import Cocoa
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let appState = AppState()
    private var overlayManager: OverlayWindowManager?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private var diagnosticsWindow: NSWindow?
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Create full-screen transparent click-through overlays
        overlayManager = OverlayWindowManager(appState: appState)

        // Setup sleek Menu Bar Status Item
        setupStatusItem()

        // Setup global shortcut monitor (Ctrl+Option+Cmd+M)
        setupGlobalShortcut()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = MenuBarIcon.create(isActive: appState.isEnabled)
            button.action = #selector(togglePopover)
            button.target = self
        }
        self.statusItem = item

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 290, height: 350)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(
                appState: appState,
                onOpenDiagnostics: { [weak self] in
                    self?.openDiagnostics()
                },
                onOpenSettings: { [weak self] in
                    self?.openSettings()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func setupGlobalShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Ctrl+Option+Cmd+M
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.control, .option, .command] && event.charactersIgnoringModifiers?.lowercased() == "m" {
                guard let self = self else { return event }
                self.appState.isEnabled.toggle()
                self.overlayManager?.updateVisibility()
                self.statusItem?.button?.image = MenuBarIcon.create(isActive: self.appState.isEnabled)
                return nil
            }
            return event
        }
    }

    public func openDiagnostics() {
        popover?.performClose(nil)

        if let win = diagnosticsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 510),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "MacDots Diagnostics & Live Telemetry"
        win.contentView = NSHostingView(rootView: DiagnosticsWindowView(appState: appState))
        win.isReleasedWhenClosed = false
        self.diagnosticsWindow = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func openSettings() {
        popover?.performClose(nil)

        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "MacDots Preferences & Research"
        win.contentView = NSHostingView(rootView: SettingsWindowView(appState: appState))
        win.isReleasedWhenClosed = false
        self.settingsWindow = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
