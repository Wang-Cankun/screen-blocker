import AppKit
import Foundation

class BlockingOverlayController: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        createOverlayWindows()
    }

    func createOverlayWindows() {
        // Cover all screens
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            windows.append(window)
        }

        // Add dismiss UI to main screen window
        if let mainWindow = windows.first {
            addDismissUI(to: mainWindow)
        }

        // Show all windows
        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }

        // Activate app to ensure focus
        NSApp.activate(ignoringOtherApps: true)
    }

    func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Set window level above fullscreen apps
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = true
        window.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.95)
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        return window
    }

    func addDismissUI(to window: NSWindow) {
        guard let contentView = window.contentView else { return }

        // Container view centered
        let containerWidth: CGFloat = 500
        let containerHeight: CGFloat = 300
        let containerX = (contentView.bounds.width - containerWidth) / 2
        let containerY = (contentView.bounds.height - containerHeight) / 2

        let container = NSView(frame: NSRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        container.layer?.cornerRadius = 16
        contentView.addSubview(container)

        // Warning icon
        let warningLabel = NSTextField(labelWithString: "⚠️")
        warningLabel.font = NSFont.systemFont(ofSize: 64)
        warningLabel.alignment = .center
        warningLabel.frame = NSRect(x: 0, y: 200, width: containerWidth, height: 80)
        container.addSubview(warningLabel)

        // Title
        let titleLabel = NSTextField(labelWithString: "Screen Sharing Warning")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 0, y: 160, width: containerWidth, height: 36)
        container.addSubview(titleLabel)

        // Message
        let messageLabel = NSTextField(labelWithString: "Sensitive content detected in browser tabs.\nClose those tabs before sharing your screen.")
        messageLabel.font = NSFont.systemFont(ofSize: 14)
        messageLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        messageLabel.alignment = .center
        messageLabel.backgroundColor = .clear
        messageLabel.isBordered = false
        messageLabel.isEditable = false
        messageLabel.maximumNumberOfLines = 3
        messageLabel.frame = NSRect(x: 20, y: 100, width: containerWidth - 40, height: 50)
        container.addSubview(messageLabel)

        // Dismiss button
        let button = NSButton(title: "I Have Closed Sensitive Tabs", target: self, action: #selector(dismissOverlay))
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        button.frame = NSRect(x: (containerWidth - 250) / 2, y: 40, width: 250, height: 40)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemRed.cgColor
        button.layer?.cornerRadius = 8
        container.addSubview(button)

        // Keyboard hint
        let hintLabel = NSTextField(labelWithString: "Press ESC to dismiss")
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        hintLabel.alignment = .center
        hintLabel.backgroundColor = .clear
        hintLabel.isBordered = false
        hintLabel.isEditable = false
        hintLabel.frame = NSRect(x: 0, y: 10, width: containerWidth, height: 20)
        container.addSubview(hintLabel)

        // Add escape key handler
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.dismissOverlay()
                return nil
            }
            return event
        }
    }

    @objc func dismissOverlay() {
        for window in windows {
            window.orderOut(nil)
        }
        NSApp.terminate(nil)
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = BlockingOverlayController()
app.delegate = delegate
app.setActivationPolicy(.accessory) // No dock icon
app.run()
