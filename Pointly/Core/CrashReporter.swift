import Foundation

/// Lightweight crash reporter — writes structured logs to ~/Library/Logs/Pointly/
enum CrashReporter {
    static func setup() {
        NSSetUncaughtExceptionHandler { exception in
            writeCrashLog(
                name: exception.name.rawValue,
                reason: exception.reason ?? "no reason",
                callStack: exception.callStackSymbols
            )
        }

        for sig in [SIGABRT, SIGSEGV, SIGILL, SIGBUS, SIGFPE] {
            signal(sig) { signum in
                writeCrashLog(
                    name: signalName(signum),
                    reason: "Received fatal signal \(signum)",
                    callStack: Thread.callStackSymbols
                )
                // Re-raise so the OS records the exit code correctly
                signal(signum, SIG_DFL)
                raise(signum)
            }
        }
    }

    private static func writeCrashLog(name: String, reason: String, callStack: [String]) {
        guard let logsDir = logsDirectory() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let file = logsDir.appendingPathComponent("crash_\(formatter.string(from: Date())).log")

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

    private static func logsDirectory() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let dir = lib.appendingPathComponent("Logs/Pointly")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGILL:  return "SIGILL"
        case SIGBUS:  return "SIGBUS"
        case SIGFPE:  return "SIGFPE"
        default:      return "Signal(\(sig))"
        }
    }
}
