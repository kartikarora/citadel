import AppKit
import SwiftUI
import CitadelUI

@MainActor
final class BrandDemoAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Font.registerBrandFonts()
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "@kartikarora v2.0.0 — Brand Component Demo"
        win.contentView = NSHostingView(rootView: BrandComponentDemoView())
        win.makeKeyAndOrderFront(nil)
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = BrandDemoAppDelegate()
app.delegate = delegate
app.run()
