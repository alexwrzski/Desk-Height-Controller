//
//  DeskControllerApp.swift
//  DeskController
//
//  Main SwiftUI App Entry Point
//

import SwiftUI
import AppKit

@main
struct DeskControllerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .background(WindowAccessor())
                .onPreferenceChange(WindowHeightKey.self) { height in
                    // Update window size when height preference changes, keeping top edge fixed
                    DispatchQueue.main.async {
                        if let window = NSApplication.shared.windows.first {
                            let oldFrame = window.frame
                            let contentSize = NSSize(width: 300, height: height)
                            let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
                            
                            // Calculate new origin to keep top edge fixed
                            let heightDifference = frameSize.height - oldFrame.size.height
                            let newOrigin = NSPoint(x: oldFrame.origin.x, y: oldFrame.origin.y - heightDifference)
                            let newFrame = NSRect(origin: newOrigin, size: frameSize)
                            
                            // Animate the resize smoothly
                            NSAnimationContext.runAnimationGroup { context in
                                context.duration = 0.2
                                context.allowsImplicitAnimation = true
                                window.setFrame(newFrame, display: true)
                            }
                            
                            window.contentMinSize = contentSize
                            window.contentMaxSize = contentSize
                            WindowDelegate.shared.setLockedSize(frameSize)
                        }
                    }
                }
                .onAppear {
                    appState.startPolling()
                }
                .onDisappear {
                    appState.stopPolling()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Remove window menu items that allow resizing
            CommandGroup(replacing: .windowSize) {}
        }
    }
}

// Helper to access and configure the NSWindow
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureAllWindows()
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureAllWindows()
        }
    }
    
    private func configureAllWindows() {
        for window in NSApplication.shared.windows {
            configureWindow(window)
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Set window background color to match app background
        window.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0) // #1a1a1a
        window.isOpaque = true
        
        // Set initial size immediately - 300px width, default height (will be updated by preference)
        let initialContentSize = NSSize(width: 300, height: 600)
        let initialFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: initialContentSize)).size
        
        // Set initial size immediately to prevent default large size
        window.setContentSize(initialContentSize)
        window.contentMinSize = initialContentSize
        window.contentMaxSize = initialContentSize
        
        // Aggressively remove resizable flag
        var styleMask = window.styleMask
        styleMask.remove(.resizable)
        styleMask.remove(.fullSizeContentView)
        window.styleMask = styleMask
        
        // Set delegate
        if window.delegate == nil || !(window.delegate is WindowDelegate) {
            WindowDelegate.shared.setLockedSize(initialFrameSize)
            window.delegate = WindowDelegate.shared
        }
        
        // Wait a moment for the view to layout, then get the actual content size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Get the actual content size from the view hierarchy
            var contentSize = window.contentView?.frame.size ?? initialContentSize
            
            // Ensure width is always 300
            contentSize.width = 300
            
            // If we can find the ContentView's calculated height, use it
            if let contentView = window.contentView {
                // Try to get the size from the SwiftUI view
                let viewSize = contentView.frame.size
                if viewSize.height > 100 && viewSize.width <= 350 { // Sanity check - reasonable size
                    contentSize.height = viewSize.height
                }
            }
            
            // Update to correct size
            let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            window.setContentSize(contentSize)
            window.contentMinSize = contentSize
            window.contentMaxSize = contentSize
            WindowDelegate.shared.setLockedSize(frameSize)
            
            // Use a timer to constantly enforce non-resizable
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                // Check if window still exists
                guard window.isVisible else {
                    timer.invalidate()
                    return
                }
                
                // Constantly remove resizable flag
                if window.styleMask.contains(.resizable) {
                    var mask = window.styleMask
                    mask.remove(.resizable)
                    window.styleMask = mask
                }
                
                // Constantly enforce size
                if window.contentMinSize != contentSize {
                    window.contentMinSize = contentSize
                }
                if window.contentMaxSize != contentSize {
                    window.contentMaxSize = contentSize
                }
            }
        }
    }
}

// Window delegate to prevent resizing
class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    private var lockedSize: NSSize?
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Only prevent resizing if the size is actually changing (not just moving)
        if let locked = lockedSize {
            // Allow if it's just a position change (same size)
            if frameSize.width == locked.width && frameSize.height == locked.height {
                return frameSize // Allow movement
            }
            // Prevent size changes
            return locked
        }
        // Lock to current size on first resize attempt
        lockedSize = sender.frame.size
        return lockedSize!
    }
    
    func windowDidResize(_ notification: Notification) {
        // Only enforce size if it actually changed (not just moved)
        if let window = notification.object as? NSWindow,
           let locked = lockedSize {
            // Only enforce if size changed, not position
            if window.frame.size.width != locked.width || window.frame.size.height != locked.height {
                let oldFrame = window.frame
                let heightDifference = locked.height - oldFrame.size.height
                let newOrigin = NSPoint(x: oldFrame.origin.x, y: oldFrame.origin.y - heightDifference)
                window.setFrame(NSRect(origin: newOrigin, size: locked), display: true)
            }
        }
    }
    
    func setLockedSize(_ size: NSSize) {
        lockedSize = size
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}

