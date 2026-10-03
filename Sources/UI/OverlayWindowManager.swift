import Cocoa
import SwiftUI

/// Window controller creating click-through, non-activating, full-screen transparent overlays
/// Configured with window.sharingType = .none to prevent capture in screen recordings or screen sharing
@MainActor
public final class OverlayWindowManager {
    private var windows: [NSWindow] = []
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        setupDisplayNotifications()
        recreateWindows()
    }

    private func setupDisplayNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.recreateWindows()
            }
        }
    }

    public func recreateWindows() {
        for win in windows {
            win.orderOut(nil)
        }
        windows.removeAll()

        for screen in NSScreen.screens {
            let win = createOverlayWindow(for: screen)
            windows.append(win)
            if shouldBeVisible {
                win.orderFrontRegardless()
            }
        }

        if let primary = NSScreen.main {
            appState.reconfigurePhysics(for: primary.frame.size)
        }
    }

    private var shouldBeVisible: Bool {
        guard appState.isEnabled else { return false }
        if appState.hideWhenScreenCaptured && appState.isScreenCaptured {
            return false
        }
        return true
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let frame = screen.frame
        let window = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Essential privacy setting: window contents are excluded from all screen recordings,
        // screenshots, ScreenCaptureKit streams, and screen sharing sessions (Zoom, Meet, Teams)
        window.sharingType = .none

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let canvasView = OverlayDotCanvas(appState: appState)
        let hostingView = NSHostingView(rootView: canvasView)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
        return window
    }

    public func updateVisibility() {
        for win in windows {
            if shouldBeVisible {
                win.orderFrontRegardless()
            } else {
                win.orderOut(nil)
            }
        }
    }
}
