// Scripted mouse/keyboard driver for filming Pointly demos.
// Usage: mousetool <script-file> | mousetool -c "cmd; cmd; ..."
// Commands (coordinates in global display points, origin top-left):
//   move X Y DUR          eased cursor move
//   click X Y             left click
//   down X Y / up X Y     press / release left button
//   drag X1 Y1 X2 Y2 DUR  press, eased move, release
//   path DUR X Y X Y ...  press at first point, smooth spline through all, release
//   glide DUR X Y X Y ... same but without pressing (pointer only)
//   key CHAR MODS         keystroke, MODS like cmd+ctrl or "-" for none (CHAR may be a keycode number)
//   sleep SEC
//   pos                   print current cursor position
//   checktrust            print AXIsProcessTrusted
import Cocoa

let stepHz = 120.0

func post(_ e: CGEvent?) { e?.post(tap: .cghidEventTap) }

func mouseEvent(_ type: CGEventType, _ p: CGPoint) {
    post(CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left))
}

func ease(_ t: Double) -> Double { t < 0.5 ? 4*t*t*t : 1 - pow(-2*t + 2, 3)/2 }

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

func moveAlong(_ points: [CGPoint], dur: Double, type: CGEventType) {
    guard points.count >= 2 else { return }
    // resample catmull-rom through points
    var pts: [CGPoint] = []
    let n = max(Int(dur * stepHz), 8)
    for i in 0...n {
        let t = ease(Double(i) / Double(n)) * Double(points.count - 1)
        let seg = min(Int(t), points.count - 2)
        let f = t - Double(seg)
        let p0 = points[max(seg-1, 0)], p1 = points[seg], p2 = points[seg+1], p3 = points[min(seg+2, points.count-1)]
        // catmull-rom
        let x = 0.5 * ((2*p1.x) + (-p0.x + p2.x)*f + (2*p0.x - 5*p1.x + 4*p2.x - p3.x)*f*f + (-p0.x + 3*p1.x - 3*p2.x + p3.x)*f*f*f)
        let y = 0.5 * ((2*p1.y) + (-p0.y + p2.y)*f + (2*p0.y - 5*p1.y + 4*p2.y - p3.y)*f*f + (-p0.y + 3*p1.y - 3*p2.y + p3.y)*f*f*f)
        pts.append(CGPoint(x: x, y: y))
    }
    for p in pts {
        mouseEvent(type, p)
        usleep(useconds_t(1_000_000.0 / stepHz))
    }
}

func currentPos() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

func keyCode(for char: String) -> CGKeyCode? {
    if char.hasPrefix("#"), let n = UInt16(char.dropFirst()) { return CGKeyCode(n) }
    let map: [String: UInt16] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,
        "y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"9":25,"7":26,"8":28,"0":29,
        "o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46,"space":49,"delete":51,"esc":53,
        "enter":36,"/":44,".":47,"-":27,"tab":48
    ]
    return map[char.lowercased()].map { CGKeyCode($0) }
}

func pressKey(_ char: String, mods: String) {
    guard let code = keyCode(for: char) else { FileHandle.standardError.write("unknown key \(char)\n".data(using: .utf8)!); return }
    var flags: CGEventFlags = []
    for m in mods.lowercased().split(separator: "+") {
        switch m {
        case "cmd": flags.insert(.maskCommand)
        case "ctrl": flags.insert(.maskControl)
        case "shift": flags.insert(.maskShift)
        case "opt", "alt": flags.insert(.maskAlternate)
        default: break
        }
    }
    let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
    down?.flags = flags
    post(down)
    usleep(60_000)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
    up?.flags = flags
    post(up)
}

func run(_ line: String) {
    let parts = line.split(separator: " ").map(String.init)
    guard !parts.isEmpty, !parts[0].hasPrefix("#") else { return }
    func f(_ i: Int) -> Double { Double(parts[i]) ?? 0 }
    func pt(_ i: Int) -> CGPoint { CGPoint(x: f(i), y: f(i+1)) }
    switch parts[0] {
    case "checktrust":
        print("trusted=\(AXIsProcessTrusted())")
    case "pos":
        let p = currentPos(); print("pos=\(Int(p.x)),\(Int(p.y))")
    case "sleep":
        usleep(useconds_t(f(1) * 1_000_000))
    case "move":
        moveAlong([currentPos(), pt(1)], dur: f(3), type: .mouseMoved)
    case "click":
        mouseEvent(.mouseMoved, pt(1)); usleep(80_000)
        mouseEvent(.leftMouseDown, pt(1)); usleep(90_000)
        mouseEvent(.leftMouseUp, pt(1))
    case "down":
        mouseEvent(.leftMouseDown, pt(1))
    case "up":
        mouseEvent(.leftMouseUp, pt(1))
    case "drag":
        mouseEvent(.mouseMoved, pt(1)); usleep(120_000)
        mouseEvent(.leftMouseDown, pt(1)); usleep(120_000)
        moveAlong([pt(1), pt(3)], dur: f(5), type: .leftMouseDragged)
        usleep(100_000)
        mouseEvent(.leftMouseUp, pt(3))
    case "path", "glide":
        let dur = f(1)
        var pts: [CGPoint] = []
        var i = 2
        while i + 1 < parts.count { pts.append(pt(i)); i += 2 }
        guard pts.count >= 2 else { return }
        mouseEvent(.mouseMoved, pts[0]); usleep(120_000)
        if parts[0] == "path" {
            mouseEvent(.leftMouseDown, pts[0]); usleep(120_000)
            moveAlong(pts, dur: dur, type: .leftMouseDragged)
            usleep(100_000)
            mouseEvent(.leftMouseUp, pts.last!)
        } else {
            moveAlong(pts, dur: dur, type: .mouseMoved)
        }
    case "key":
        pressKey(parts[1], mods: parts.count > 2 ? parts[2] : "-")
    case "type":
        let text = parts.dropFirst().joined(separator: " ")
        for ch in text {
            let s = String(ch), lower = s.lowercased()
            guard let code = keyCode(for: s == " " ? "space" : lower) else { continue }
            let shift = (s != lower)
            let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
            if shift { d?.flags = .maskShift }
            post(d); usleep(28_000)
            let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
            if shift { u?.flags = .maskShift }
            post(u); usleep(22_000)
        }
    case "activate":
        if let pid = Int32(parts[1]), let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
            usleep(400_000)
            print("activated pid=\(pid) \(app.localizedName ?? "?")")
        } else { FileHandle.standardError.write("no app for pid \(parts[1])\n".data(using: .utf8)!) }
    case "screen":
        if let s = NSScreen.main { print("screen=\(Int(s.frame.width)),\(Int(s.frame.height)) scale=\(s.backingScaleFactor)") }
    case "wins":
        // list on-screen windows: owner, layer, frame (optionally filter by owner name in parts[1])
        let filter = parts.count > 1 ? parts[1].lowercased() : nil
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                let owner = (w[kCGWindowOwnerName as String] as? String) ?? "?"
                if let f = filter, !owner.lowercased().contains(f) { continue }
                let layer = (w[kCGWindowLayer as String] as? Int) ?? 0
                let b = (w[kCGWindowBounds as String] as? [String: Any]) ?? [:]
                let name = (w[kCGWindowName as String] as? String) ?? ""
                print("win owner=\(owner) name=\(name) layer=\(layer) x=\(b["X"] ?? 0) y=\(b["Y"] ?? 0) w=\(b["Width"] ?? 0) h=\(b["Height"] ?? 0)")
            }
        }
    default:
        FileHandle.standardError.write("unknown cmd: \(line)\n".data(using: .utf8)!)
    }
}

let args = CommandLine.arguments
var lines: [String] = []
if args.count >= 3 && args[1] == "-c" {
    lines = args[2].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
} else if args.count >= 2 {
    lines = (try? String(contentsOfFile: args[1], encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
} else {
    print("usage: mousetool <script>|-c \"cmds\"")
    exit(1)
}
for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
    run(line.trimmingCharacters(in: .whitespaces))
}
