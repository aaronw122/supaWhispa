// key-listener.swift
import Cocoa

// Fn/Globe key shows up as a flag change, not a regular key event.
// NSEvent.ModifierFlags.function = 0x800000
let FN_FLAG: UInt64 = 0x800000

var fnIsDown = false
var eventTap: CFMachPort?

func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) ->
    Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        if type == .flagsChanged {
            let flags = event.flags.rawValue
            let fnNow = (flags & FN_FLAG) != 0

            if fnNow && !fnIsDown {
                print("DOWN")
                fflush(stdout)
                fnIsDown = true
            } else if !fnNow && fnIsDown {
                print("UP")
                fflush(stdout)
                fnIsDown = false
            }
        }
        return Unmanaged.passUnretained(event)
    }

let mask = (1 << CGEventType.flagsChanged.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: nil
) else {
    print("ERROR: Enable Accessibility in System Settings > Privacy & Security")
    exit(1)
}

eventTap = tap
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRun()
