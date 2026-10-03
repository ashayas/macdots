import Foundation

/// Central coordinator for motion data telemetry sources
public final class SensorManager: @unchecked Sendable {
    public let hardwareIMU = AppleSiliconIMU()
    public let simulator = MotionSimulator()

    public private(set) var activeSourceType: SensorSourceType = .hardwareIMU
    public var onSample: (@Sendable (MotionSample) -> Void)?

    private var lock = os_unfair_lock()
    private var isRunning = false

    public init() {
        // Automatically default to hardware IMU if available, otherwise simulator
        if hardwareIMU.isAvailable {
            activeSourceType = .hardwareIMU
        } else {
            activeSourceType = .simulator
        }
    }

    public var isHardwareAvailable: Bool {
        hardwareIMU.isAvailable
    }

    public func setSource(_ type: SensorSourceType) {
        os_unfair_lock_lock(&lock)
        guard type != activeSourceType else {
            os_unfair_lock_unlock(&lock)
            return
        }
        let wasRunning = isRunning
        activeSourceType = type
        os_unfair_lock_unlock(&lock)

        if wasRunning {
            stop()
            start(handler: onSample ?? { _ in })
        }
    }

    public func start(handler: @escaping @Sendable (MotionSample) -> Void) {
        os_unfair_lock_lock(&lock)
        self.onSample = handler
        self.isRunning = true
        let source = self.activeSourceType
        os_unfair_lock_unlock(&lock)

        let forwardSample: @Sendable (MotionSample) -> Void = { [weak self] sample in
            self?.onSample?(sample)
        }

        switch source {
        case .hardwareIMU:
            if hardwareIMU.isAvailable {
                hardwareIMU.start(handler: forwardSample)
            } else {
                // Fallback to simulator if hardware not available
                simulator.start(handler: forwardSample)
            }
        case .simulator, .manual:
            simulator.start(handler: forwardSample)
        }
    }

    public func stop() {
        os_unfair_lock_lock(&lock)
        self.isRunning = false
        os_unfair_lock_unlock(&lock)

        hardwareIMU.stop()
        simulator.stop()
    }
}
