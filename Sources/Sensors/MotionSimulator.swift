import Foundation

/// Realistic physics-based vehicle motion simulator
/// Accurately simulates the kinematic forces felt inside buses, airplanes, trains, and cars.
public final class MotionSimulator: @unchecked Sendable, MotionSensorProtocol {
    public let sourceType: SensorSourceType = .simulator
    public let isAvailable: Bool = true
    public private(set) var isRunning: Bool = false

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.macdots.simulator", qos: .userInteractive)
    private var handler: (@Sendable (MotionSample) -> Void)?

    private var profile: VehicleProfile = .cityBus
    private var startTime: TimeInterval = 0
    private var lock = os_unfair_lock()

    // Manual injection forces (from diagnostics or UI joystick)
    private var manualOffset = Vector3.zero

    public init(initialProfile: VehicleProfile = .cityBus) {
        self.profile = initialProfile
    }

    public func setProfile(_ newProfile: VehicleProfile) {
        os_unfair_lock_lock(&lock)
        self.profile = newProfile
        os_unfair_lock_unlock(&lock)
    }

    public func injectImpulse(lateral: Double, longitudinal: Double, duration: TimeInterval = 0.5) {
        os_unfair_lock_lock(&lock)
        manualOffset = Vector3(x: lateral, y: longitudinal, z: 0)
        os_unfair_lock_unlock(&lock)

        queue.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            os_unfair_lock_lock(&self.lock)
            self.manualOffset = .zero
            os_unfair_lock_unlock(&self.lock)
        }
    }

    public func setManualForce(x: Double, y: Double) {
        os_unfair_lock_lock(&lock)
        manualOffset = Vector3(x: x, y: y, z: 0)
        os_unfair_lock_unlock(&lock)
    }

    public func start(handler: @escaping @Sendable (MotionSample) -> Void) {
        guard !isRunning else { return }
        self.handler = handler
        self.isRunning = true
        self.startTime = ProcessInfo.processInfo.systemUptime

        let t = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2)) // ~60 Hz simulation
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        self.timer = t
        t.resume()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - startTime

        os_unfair_lock_lock(&lock)
        let currentProfile = self.profile
        let manual = self.manualOffset
        os_unfair_lock_unlock(&lock)

        var accel = Vector3(x: 0, y: 0, z: -1.0) // 1g downward gravity baseline
        var gyro = Vector3.zero

        switch currentProfile {
        case .cityBus:
            accel = computeBusForces(t: elapsed)
        case .airplane:
            accel = computeAirplaneForces(t: elapsed)
        case .subway:
            accel = computeSubwayForces(t: elapsed)
        case .highwayCar:
            accel = computeHighwayCarForces(t: elapsed)
        case .mountainRoad:
            accel = computeMountainRoadForces(t: elapsed)
        }

        // Add any manual joystick/impulse override
        accel.x += manual.x
        accel.y += manual.y

        // Gyro angular rates derived from lateral acceleration (approximate banking/yaw rate)
        gyro.z = accel.x * 25.0 // Yaw rate ~ 25 deg/s per g
        gyro.x = accel.y * 10.0 // Pitch rate

        let sample = MotionSample(
            timestamp: now,
            acceleration: accel,
            rotationRate: gyro,
            sourceType: .simulator
        )

        handler?(sample)
    }

    // MARK: - Vehicle Simulation Models

    /// Simulates a 32-second recurring city bus route segment:
    /// - 0..4s: Stationary at stop
    /// - 4..9s: Forward acceleration out of stop
    /// - 9..14s: Cruising speed with road roughness
    /// - 14..18s: Sharp 90° right corner turn
    /// - 18..22s: Brief acceleration
    /// - 22..25s: 90° left turn
    /// - 25..29s: Heavy braking for the next stop
    /// - 29..32s: Settling to complete stop
    private func computeBusForces(t: TimeInterval) -> Vector3 {
        let cycle = t.truncatingRemainder(dividingBy: 32.0)
        var ax = 0.0 // Lateral (left/right)
        var ay = 0.0 // Longitudinal (forward/braking)
        var az = -1.0 // Vertical (gravity + bumps)

        // Road texture / engine vibration (small high frequency)
        let engineHum = sin(t * 22.0) * 0.008

        if cycle < 4.0 {
            // Stationary at stop
            ax = 0.0
            ay = 0.0
            az = -1.0 + engineHum
        } else if cycle < 9.0 {
            // Accelerating forward (inertia pulls backward: ay < 0 in device frame)
            let progress = (cycle - 4.0) / 5.0
            let ramp = sin(progress * .pi)
            ay = -0.20 * ramp // backward inertial push
            ax = sin(t * 2.0) * 0.015
            az = -1.0 + sin(t * 12.0) * 0.02
        } else if cycle < 14.0 {
            // Cruising at 50 km/h with pavement bumps
            ay = sin(t * 0.8) * 0.02
            ax = sin(t * 0.5) * 0.02
            let bump = (sin(t * 7.0) > 0.8) ? 0.06 : 0.0
            az = -1.0 + bump + sin(t * 15.0) * 0.025
        } else if cycle < 18.0 {
            // Turning right: centrifugal force pulls to the left (ax < 0)
            let turnProgress = (cycle - 14.0) / 4.0
            let turnEnvelope = sin(turnProgress * .pi)
            ax = -0.28 * turnEnvelope
            ay = -0.05 * turnEnvelope // slight braking into corner
            az = -1.0 + sin(t * 10.0) * 0.02
        } else if cycle < 22.0 {
            // Short straightaway
            ay = -0.15 * sin((cycle - 18.0) / 4.0 * .pi)
            ax = 0.01
            az = -1.0 + sin(t * 14.0) * 0.02
        } else if cycle < 25.0 {
            // Turning left: centrifugal force pulls to the right (ax > 0)
            let turnProgress = (cycle - 22.0) / 3.0
            let turnEnvelope = sin(turnProgress * .pi)
            ax = 0.25 * turnEnvelope
            ay = 0.0
            az = -1.0
        } else if cycle < 29.0 {
            // Hard braking into next stop (inertia throws forward: ay > 0)
            let brakeProgress = (cycle - 25.0) / 4.0
            let brakeEnvelope = sin(brakeProgress * .pi)
            ay = 0.32 * brakeEnvelope // forward slide
            ax = sin(t * 1.5) * 0.01
            az = -1.0 - 0.04 * brakeEnvelope // front suspension dip
        } else {
            // Settling back to idle
            let settle = (cycle - 29.0) / 3.0
            ay = 0.05 * (1.0 - settle) * sin(t * 4.0)
            ax = 0.0
            az = -1.0 + engineHum
        }

        return Vector3(x: ax, y: ay, z: az)
    }

    /// Simulates commercial airline flight:
    /// - High altitude cruise
    /// - Periodic multi-axis atmospheric turbulence chops
    /// - Gentle coordinated banking turns
    private func computeAirplaneForces(t: TimeInterval) -> Vector3 {
        // Multi-frequency Perlin-like atmospheric turbulence synthesis
        let chop1 = sin(t * 1.3) * 0.08
        let chop2 = sin(t * 3.7 + 1.2) * 0.05
        let chop3 = sin(t * 7.1 + 0.4) * 0.03
        let gust = (sin(t * 0.2) > 0.7) ? (sin(t * 4.5) * 0.15) : 0.0

        let verticalTurbulence = chop1 + chop2 + chop3 + gust

        // Gentle banking turn cycle every 45s
        let turnCycle = t.truncatingRemainder(dividingBy: 45.0)
        var ax = 0.0
        var ay = 0.0

        if turnCycle > 15.0 && turnCycle < 30.0 {
            let turnP = (turnCycle - 15.0) / 15.0
            let bank = sin(turnP * .pi)
            ax = 0.14 * bank // Lateral banking
        }

        // Mild high-altitude jet buffet
        let lateralTurbulence = sin(t * 1.8 + 0.5) * 0.04 + sin(t * 4.2) * 0.03

        ax += lateralTurbulence
        ay += sin(t * 0.7) * 0.015 // slight pitch fluctuation
        let az = -1.0 + verticalTurbulence

        return Vector3(x: ax, y: ay, z: az)
    }

    /// Simulates railway / train / subway travel:
    /// - Characteristic rhythmic track sway (hunting oscillation ~ 1.2 Hz)
    /// - Switch points / track crossings
    /// - Gradual acceleration and station stops
    private func computeSubwayForces(t: TimeInterval) -> Vector3 {
        let cycle = t.truncatingRemainder(dividingBy: 40.0)
        var ax = 0.0
        var ay = 0.0
        var az = -1.0

        // Train track sway (hunting oscillation)
        let trackSway = sin(t * 1.4) * 0.05 + sin(t * 2.8) * 0.02
        let trackClick = (sin(t * 2.5) > 0.92) ? 0.04 : 0.0

        if cycle < 10.0 {
            // Leaving station: smooth sustained acceleration
            let ramp = sin((cycle / 10.0) * .pi)
            ay = -0.16 * ramp
            ax = trackSway * 0.6
        } else if cycle < 28.0 {
            // High speed cruise with track curves
            let curve = sin(cycle * 0.25) * 0.12
            ax = trackSway + curve
            ay = sin(t * 0.3) * 0.01
        } else {
            // Decelerating into station
            let ramp = sin(((cycle - 28.0) / 12.0) * .pi)
            ay = 0.18 * ramp
            ax = trackSway * 0.4
        }

        az = -1.0 + trackClick + sin(t * 8.0) * 0.015
        return Vector3(x: ax, y: ay, z: az)
    }

    /// Simulates car driving on highway: lane changes, speed fluctuations
    private func computeHighwayCarForces(t: TimeInterval) -> Vector3 {
        let cycle = t.truncatingRemainder(dividingBy: 20.0)
        var ax = sin(t * 0.4) * 0.03
        let ay = sin(t * 0.2) * 0.02

        // Lane change every 20 seconds: quick steer left then right
        if cycle > 8.0 && cycle < 13.0 {
            let lcP = (cycle - 8.0) / 5.0
            // Double impulse for lane change: left then right
            ax += sin(lcP * .pi * 2.0) * 0.18
        }

        let roadTexture = sin(t * 18.0) * 0.02
        let az = -1.0 + roadTexture

        return Vector3(x: ax, y: ay, z: az)
    }

    /// Simulates mountain road driving with continuous curves and elevation
    private func computeMountainRoadForces(t: TimeInterval) -> Vector3 {
        // Continuous sweeping S-curves
        let sCurve = sin(t * 0.6) * 0.28 + sin(t * 1.3) * 0.12
        // Braking into curves and accelerating out
        let throttle = -cos(t * 0.6) * 0.15

        let ax = sCurve
        let ay = throttle
        let az = -1.0 + sin(t * 12.0) * 0.025

        return Vector3(x: ax, y: ay, z: az)
    }

    deinit {
        stop()
    }
}
