import Foundation

/// Protocol for all motion telemetry sources
public protocol MotionSensorProtocol: AnyObject, Sendable {
    var sourceType: SensorSourceType { get }
    var isAvailable: Bool { get }
    var isRunning: Bool { get }

    func start(handler: @escaping @Sendable (MotionSample) -> Void)
    func stop()
}
