import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Create custom icon view that passes through mouse events
            let iconView = UsageIconView()
            let hostingView = ClickThroughHostingView(rootView: iconView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 80, height: 22)
            button.addSubview(hostingView)
            button.frame = hostingView.frame
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 10)
        popover.behavior = .transient
        
        let contentView = ContentView()
            .environment(\.colorScheme, .dark)
        let hostingController = NSHostingController(rootView: contentView)
        
        popover.contentViewController = hostingController
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

/// An NSHostingView subclass that passes all mouse events through to its superview (the status bar button).
class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
