#!/usr/bin/env swift
//
//  key-monitor.swift
//
//  Prints every keyboard event the system sees: key down/up and modifier
//  changes, with the virtual keycode, the flags it carries and the process
//  that posted it. Listen-only — it never changes or swallows an event.
//
//  Run:   swift tools/key-monitor.swift      (Ctrl-C to stop)
//  Needs: the terminal app allowed in Privacy & Security → Input Monitoring
//         (or Accessibility), otherwise the tap cannot be created.
//

import Cocoa

let names: [Int64: String] = [
    51: "Backspace", 117: "ForwardDelete", 36: "Return", 48: "Tab", 49: "Space", 53: "Escape",
    55: "Cmd(L)", 54: "Cmd(R)", 56: "Shift(L)", 60: "Shift(R)", 58: "Alt(L)", 61: "Alt(R)",
    59: "Ctrl(L)", 62: "Ctrl(R)", 63: "fn", 57: "CapsLock",
    123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "PageUp", 121: "PageDown",
    0: "A", 8: "C", 9: "V", 6: "Z", 7: "X",
]

func flagsString(_ f: CGEventFlags) -> String {
    var parts: [String] = []
    if f.contains(.maskCommand)     { parts.append("⌘") }
    if f.contains(.maskControl)     { parts.append("⌃") }
    if f.contains(.maskAlternate)   { parts.append("⌥") }
    if f.contains(.maskShift)       { parts.append("⇧") }
    if f.contains(.maskSecondaryFn) { parts.append("fn") }
    if f.contains(.maskAlphaShift)  { parts.append("⇪") }
    return parts.isEmpty ? "-" : parts.joined()
}

func processName(_ pid: Int64) -> String {
    if pid == 0 { return "hardware" }
    return NSRunningApplication(processIdentifier: pid_t(pid))?.localizedName ?? "pid \(pid)"
}

let timeFormat: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

let mask = (1 << CGEventType.keyDown.rawValue)
         | (1 << CGEventType.keyUp.rawValue)
         | (1 << CGEventType.flagsChanged.rawValue)

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("!! tap disabled (\(type.rawValue)), events may have been missed")
        return Unmanaged.passUnretained(event)
    }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
    let kind: String
    switch type {
    case .keyDown:      kind = event.getIntegerValueField(.keyboardEventAutorepeat) != 0 ? "DOWN(rep)" : "DOWN"
    case .keyUp:        kind = "UP"
    case .flagsChanged: kind = "FLAGS"
    default:            kind = "type \(type.rawValue)"
    }
    var length = 0
    var chars = [UniChar](repeating: 0, count: 8)
    event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
    let text = String(utf16CodeUnits: chars, count: length)
        .unicodeScalars.map { $0.value < 0x20 || $0.value == 0x7F ? String(format: "\\u{%02X}", $0.value) : String($0) }
        .joined()
    let name = names[code] ?? "?"
    let line = String(format: "%@  %-9@ code=%3lld %-14@ flags=%-6@ chars=%-8@ from=%@",
                      timeFormat.string(from: Date()), kind, code, name,
                      flagsString(event.flags), "\"\(text)\"", processName(pid))
    print(line)
    fflush(stdout)
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .listenOnly,
                                  eventsOfInterest: CGEventMask(mask),
                                  callback: callback,
                                  userInfo: nil) else {
    print("Cannot create the event tap. Allow your terminal in System Settings → Privacy & Security → Input Monitoring, then run again.")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("Listening for keyboard events. Ctrl-C to stop.")
CFRunLoopRun()
