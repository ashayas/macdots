import Foundation

/// 3D Vector for physical kinematics (acceleration in g, rotation in deg/s, positions in pt)
public struct Vector3: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }

    public var magnitude2D: Double {
        sqrt(x * x + y * y)
    }

    public var normalized: Vector3 {
        let mag = magnitude
        guard mag > 1e-6 else { return .zero }
        return Vector3(x: x / mag, y: y / mag, z: z / mag)
    }

    public static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func / (lhs: Vector3, rhs: Double) -> Vector3 {
        guard abs(rhs) > 1e-9 else { return .zero }
        return Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }

    public static prefix func - (v: Vector3) -> Vector3 {
        Vector3(x: -v.x, y: -v.y, z: -v.z)
    }

    public func lerp(to target: Vector3, t: Double) -> Vector3 {
        let clampedT = max(0.0, min(1.0, t))
        return self + (target - self) * clampedT
    }
}

/// Source of motion sensor telemetry
public enum SensorSourceType: String, CaseIterable, Identifiable, Codable, Sendable {
    case hardwareIMU = "Apple Silicon IMU"
    case simulator = "Vehicle Simulator"
    case manual = "Manual Joystick"

    public var id: String { rawValue }
}

/// Real-world vehicle motion profiles for the simulator
public enum VehicleProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case cityBus = "City Bus"
    case airplane = "Commercial Airplane"
    case subway = "Train / Subway"
    case highwayCar = "Highway Car"
    case mountainRoad = "Winding Mountain Road"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .cityBus: return "bus.fill"
        case .airplane: return "airplane"
        case .subway: return "tram.fill"
        case .highwayCar: return "car.fill"
        case .mountainRoad: return "road.lanes.curved.right"
        }
    }

    public var description: String {
        switch self {
        case .cityBus:
            return "Frequent stop-and-go acceleration, heavy bus stop braking, sharp 90° cornering, and road surface bumps."
        case .airplane:
            return "Continuous high-speed cruise, atmospheric turbulence chops, slow banked turns, and takeoff acceleration."
        case .subway:
            return "Rhythmic rail sway, switch crossings, gradual acceleration, and station deceleration."
        case .highwayCar:
            return "High-speed lane changes, gentle curves, and sustained speed with minor road vibrations."
        case .mountainRoad:
            return "Continuous alternating S-curves, hairpin turns, elevation gradient changes, and braking."
        }
    }
}

/// Instantaneous motion telemetry packet
public struct MotionSample: Sendable {
    public let timestamp: TimeInterval
    public let acceleration: Vector3    // In units of g (1.0g = 9.80665 m/s^2)
    public let rotationRate: Vector3    // In degrees/sec (Roll, Pitch, Yaw)
    public let sourceType: SensorSourceType

    public init(
        timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime,
        acceleration: Vector3,
        rotationRate: Vector3 = .zero,
        sourceType: SensorSourceType
    ) {
        self.timestamp = timestamp
        self.acceleration = acceleration
        self.rotationRate = rotationRate
        self.sourceType = sourceType
    }
}

/// Detected vehicle kinematic motion state
public enum VehicleMotionState: String, Sendable {
    case stationary = "Stationary / Idle"
    case accelerating = "Accelerating Forward"
    case braking = "Decelerating / Braking"
    case turningLeft = "Turning Left"
    case turningRight = "Turning Right"
    case cruising = "Cruising at Steady Speed"
    case turbulence = "Turbulence / Bumpy Road"

    public var icon: String {
        switch self {
        case .stationary: return "pause.circle.fill"
        case .accelerating: return "arrow.up.circle.fill"
        case .braking: return "arrow.down.circle.fill"
        case .turningLeft: return "arrow.left.circle.fill"
        case .turningRight: return "arrow.right.circle.fill"
        case .cruising: return "checkmark.circle.fill"
        case .turbulence: return "waveform.path.ecg"
        }
    }
}
