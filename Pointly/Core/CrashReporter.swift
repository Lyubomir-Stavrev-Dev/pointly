import Foundation

// MARK: - Top-level handlers (C function pointers cannot capture context)

// Previous handler (e.g. from an SDK) — chained so setup() doesn't silently
// disable it. Global, not a capture, so the C function pointer stays valid.
private var _pointlyPreviousExceptionHandler: (@convention(c) (NSException) -> Void)? = nil

private func _pointlyUncaughtExceptionHandler(_ exception: NSException) {
    _pointlyWriteCrashLog(
        name: exception.name.rawValue,
        reason: exception.reason ?? "no reason",
        callStack: exception.callStackSymbols
    )
    _pointlyPreviousExceptionHandler?(exception)
}

private func _pointlySignalHandler(_ sig: Int32) {
    let name: String
    switch sig {
    case SIGABRT: name = "SIGABRT"
    case SIGSEGV: name = "SIGSEGV"
    case SIGILL:  name = "SIGILL"
    case SIGBUS:  name = "SIGBUS"
    case SIGFPE:  name = "SIGFPE"
    default:      name = "Signal(\(sig))"
    }
    _pointlyWriteCrashLog(
        name: name,
        reason: "Received fatal signal \(sig)",
        callStack: Thread.callStackSymbols
    )
    signal(sig, SIG_DFL)
    raise(sig)
}

private func _pointlyWriteCrashLog(name: String, reason: String, callStack: [String]) {
    guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
    let dir = lib.appendingPathComponent("Logs/Pointly")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let file = dir.appendingPathComponent("crash_\(formatter.string(from: Date())).log")

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    let os      = ProcessInfo.processInfo.operatingSystemVersionString

    let content = """
    Pointly Crash Report
    ====================
    Date:    \(Date())
    Version: \(version) (\(build))
    macOS:   \(os)

    Exception: \(name)
    Reason:    \(reason)

    Call Stack:
    \(callStack.enumerated().map { "\($0.offset)  \($0.element)" }.joined(separator: "\n"))
    """

    try? content.write(to: file, atomically: true, encoding: .utf8)
}

// MARK: - Public Setup

enum CrashReporter {
    static func setup() {
        _pointlyPreviousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(_pointlyUncaughtExceptionHandler)
        // Signal handlers re-raise with SIG_DFL after logging, preserving the
        // system crash reporter. (Note: the handler body is not strictly
        // async-signal-safe — acceptable trade-off for best-effort local logs.)
        for sig in [SIGABRT, SIGSEGV, SIGILL, SIGBUS, SIGFPE] {
            signal(sig, _pointlySignalHandler)
        }
    }
}
