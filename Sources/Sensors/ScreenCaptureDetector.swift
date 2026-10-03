import Cocoa
import CoreGraphics

/// Monitors system state to detect active screen recording, screen sharing, or presentation sessions
public final class ScreenCaptureDetector: @unchecked Sendable {
    public var onCaptureStateChanged: (@Sendable (Bool) -> Void)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.macdots.screencapture", qos: .utility)
    private var isCapturing = false
    private var lock = os_unfair_lock()

    // Known bundle IDs and process names for screen capture / sharing
    private let captureProcessNames: Set<String> = [
        "screencapture",
        "screencaptureui",
        "replayd",
        "screensharingd"
    ]

    public init() {}

    public func start(handler: @escaping @Sendable (Bool) -> Void) {
        os_unfair_lock_lock(&lock)
        self.onCaptureStateChanged = handler
        os_unfair_lock_unlock(&lock)

        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in
            self?.checkCaptureState()
        }
        self.timer = t
        t.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    private func checkCaptureState() {
        var capturingDetected = false

        // 1. Inspect running system applications and daemons
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let name = app.localizedName?.lowercased() {
                if name == "screencapture" || name == "screencaptureui" || name == "screensharingd" {
                    capturingDetected = true
                    break
                }
            }
        }

        // 2. Check window list for system capture indicator windows
        if !capturingDetected {
            if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
                for win in windowList {
                    if let ownerName = win[kCGWindowOwnerName as String] as? String {
                        let lower = ownerName.lowercased()
                        if lower == "screencapture" || lower == "screencaptureui" || lower == "replayd" {
                            capturingDetected = true
                            break
                        }
                    }
                }
            }
        }

        os_unfair_lock_lock(&lock)
        let stateChanged = (capturingDetected != isCapturing)
        isCapturing = capturingDetected
        os_unfair_lock_unlock(&lock)

        if stateChanged {
            onCaptureStateChanged?(capturingDetected)
        }
    }

    deinit {
        stop()
    }
}
