import Foundation

/// Processed motion state incorporating research-backed vestibular-ocular compensations
public struct ProcessedMotion: Sendable {
    public let rawAcceleration: Vector3
    public let rawRotationRate: Vector3
    public let dynamicAcceleration: Vector3 // Gravity baseline removed & low-pass filtered
    public let inertialForce: Vector3      // Passenger inertial force (includes anticipatory feed-forward)
    public let jerk: Vector3               // Rate of change of acceleration (da/dt in g/s)
    public let rollAngleRad: Double        // Artificial horizon roll banking angle (radians)
    public let pitchAngleRad: Double       // Pitch angle (radians)
    public let radialExpansion: Double     // 3D optic flow depth expansion/contraction
    public let vagalPulse: Double          // 0.0 to 1.0 respiratory pacing wave when stationary
    public let vignetteOpacity: Double     // Dynamic peripheral vision blocking intensity (0.0 to 0.7)
    public let state: VehicleMotionState
    public let activityLevel: Double       // 0.0 (stationary) to 1.0 (vigorous motion)
    public let fadeOpacity: Double         // 0.0 (faded out when parked) to 1.0 (active)
    public let timestamp: TimeInterval
}

/// Advanced scientific motion processor
/// - Removes static Earth gravity & auto-levels laptop tilt
/// - Rejects typing clicks and high-frequency vibrations via Butterworth low-pass filter
/// - Anticipatory Jerk Feed-Forward: Anticipates vehicle maneuvers 100-300ms before peak G-force
/// - Artificial Horizon: Computes roll banking angle to ground the brain to the true inertial horizon
/// - Optic Flow Expansion: Simulates 3D forward vection depth
/// - Dynamic Peripheral Vignette: Dampens visual sensory overload during severe >0.25g turns
/// - Autonomic Vagal Calming: Paces parasympathetic breathing when stopped in traffic
public final class MotionProcessor: @unchecked Sendable {
    // Configuration
    public var sensitivity: Double = 1.0
    public var autoFadeEnabled: Bool = true
    public var deadzoneThreshold: Double = 0.015
    public var filterCutoffHz: Double = 2.2

    // Research Feature Flags
    public var anticipatoryJerkEnabled: Bool = true  // Feeds forward vehicle jerk (da/dt)
    public var horizonTiltEnabled: Bool = true       // Enables artificial horizon tilt
    public var opticFlowDepthEnabled: Bool = true    // Enables 3D radial vection expansion
    public var dynamicVignetteEnabled: Bool = true   // Soft peripheral darkening on high-G spikes
    public var vagalCalmingEnabled: Bool = true      // 0.1 Hz soothing pulse when stopped

    // Internal State
    private var gravityBaseline = Vector3(x: 0, y: 0, z: -1.0)
    private var biquadLowPass: Vector3BiquadFilter
    private var lastSampleTime: TimeInterval = 0
    private var previousDynamic = Vector3.zero
    private var currentJerk = Vector3.zero
    private var stationaryDuration: TimeInterval = 0
    private var currentFadeOpacity: Double = 1.0
    private var currentActivity: Double = 0.0
    private var vagalBreathTimer: Double = 0.0

    private var lock = os_unfair_lock()

    public init(sampleRateHz: Double = 100.0) {
        self.biquadLowPass = Vector3BiquadFilter(cutoffHz: 2.2, sampleRateHz: sampleRateHz, isHighPass: false)
    }

    public func updateSampleRate(_ sampleRateHz: Double) {
        os_unfair_lock_lock(&lock)
        self.biquadLowPass = Vector3BiquadFilter(cutoffHz: filterCutoffHz, sampleRateHz: sampleRateHz, isHighPass: false)
        os_unfair_lock_unlock(&lock)
    }

    public func resetCalibration() {
        os_unfair_lock_lock(&lock)
        gravityBaseline = Vector3(x: 0, y: 0, z: -1.0)
        biquadLowPass.reset()
        previousDynamic = .zero
        currentJerk = .zero
        stationaryDuration = 0
        currentFadeOpacity = 1.0
        currentActivity = 0.0
        vagalBreathTimer = 0.0
        os_unfair_lock_unlock(&lock)
    }

    public func process(sample: MotionSample) -> ProcessedMotion {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let now = sample.timestamp
        let dt = (lastSampleTime > 0) ? min(0.1, max(0.001, now - lastSampleTime)) : 0.01
        lastSampleTime = now

        let raw = sample.acceleration

        // 1. Adaptive gravity baseline tracking (slow leaky integrator, tau ~ 3.5s)
        let alpha = min(1.0, dt / 3.5)
        gravityBaseline = gravityBaseline.lerp(to: raw, t: alpha)

        // 2. Subtract gravity baseline to isolate dynamic vehicle acceleration
        var dynamic = raw - gravityBaseline

        // 3. 2nd-order Butterworth low-pass filter to reject keystrokes and chassis rattle
        dynamic = biquadLowPass.process(dynamic)

        // 4. Calculate Jerk (da/dt in g/s)
        let rawJerk = (dynamic - previousDynamic) / dt
        // Smooth jerk with single-pole filter
        currentJerk = currentJerk.lerp(to: rawJerk, t: min(1.0, dt * 15.0))
        previousDynamic = dynamic

        // 5. Deadzone thresholding with soft-knee
        let rawMag2D = dynamic.magnitude2D
        if rawMag2D < deadzoneThreshold {
            dynamic.x = 0
            dynamic.y = 0
        } else {
            let scale = (rawMag2D - deadzoneThreshold) / rawMag2D
            dynamic.x *= scale
            dynamic.y *= scale
        }

        let scaledDynamic = dynamic * sensitivity

        // 6. Anticipatory Maneuver Compensation (Jerk Feed-Forward)
        // Drivers predict turns before lateral G builds up; passengers do not.
        // Adding a 120ms jerk lead feeds visual onset to the peripheral retina in real-time.
        var effectiveAccel = scaledDynamic
        if anticipatoryJerkEnabled {
            let tauJerk = 0.12 // 120ms lead
            effectiveAccel.x += currentJerk.x * tauJerk * sensitivity
            effectiveAccel.y += currentJerk.y * tauJerk * sensitivity
        }

        // 7. Inertial force vector felt by passengers
        let inertialForce = Vector3(
            x: -effectiveAccel.x,
            y: effectiveAccel.y,
            z: -effectiveAccel.z
        )

        // 8. Artificial Horizon Roll & Pitch Angle Calculation
        // Roll banking angle: phi = arctan(ax / g)
        var rollAngle = 0.0
        var pitchAngle = 0.0
        if horizonTiltEnabled {
            let effectiveG = max(0.5, abs(gravityBaseline.z))
            rollAngle = atan2(-scaledDynamic.x, effectiveG)
            pitchAngle = atan2(scaledDynamic.y, effectiveG)
        }

        // 9. Radial Optic Flow Expansion
        // Forward acceleration (ay < 0) expands optic flow outward; braking contracts inward
        var radialExp = 1.0
        if opticFlowDepthEnabled {
            // Longitudinal acceleration expands/contracts radius by up to ±15%
            radialExp = max(0.85, min(1.15, 1.0 - scaledDynamic.y * 0.45))
        }

        // 10. Activity Level & Auto-Fade Logic
        let motionIntensity = scaledDynamic.magnitude2D
        currentActivity = currentActivity * 0.90 + min(1.0, motionIntensity / 0.25) * 0.10

        let isStationary = motionIntensity < 0.025
        if isStationary {
            stationaryDuration += dt
        } else {
            stationaryDuration = 0
        }

        if autoFadeEnabled {
            if stationaryDuration > 2.5 {
                let fadeSpeed = dt * 1.5
                currentFadeOpacity = max(0.0, currentFadeOpacity - fadeSpeed)
            } else {
                let fadeInSpeed = dt * 4.0
                currentFadeOpacity = min(1.0, currentFadeOpacity + fadeInSpeed)
            }
        } else {
            currentFadeOpacity = 1.0
        }

        // 11. Autonomic Vagal Calming Pulse (0.1 Hz / 6 breaths per min)
        var vagalPulseVal = 0.0
        if vagalCalmingEnabled && isStationary && stationaryDuration > 1.0 {
            vagalBreathTimer += dt
            // Sine wave between 0.0 and 1.0 with 10s period (0.1 Hz)
            vagalPulseVal = (sin(vagalBreathTimer * 2.0 * .pi * 0.10) + 1.0) * 0.5
        } else {
            vagalBreathTimer = 0.0
        }

        // 12. Dynamic Peripheral Vignette Intensity for High-G Maneuvers
        // Beyond 0.22g, softly darkens the outermost 4% of display edges to block vection overload
        var vignetteVal = 0.0
        if dynamicVignetteEnabled && motionIntensity > 0.22 {
            let excessG = min(0.35, motionIntensity - 0.22)
            vignetteVal = (excessG / 0.35) * 0.65 // Up to 65% opacity in extreme turns
        }

        // 13. Kinematic Motion State Classification
        let state: VehicleMotionState
        if isStationary && stationaryDuration > 1.5 {
            state = .stationary
        } else if abs(scaledDynamic.x) > 0.06 && abs(scaledDynamic.x) > abs(scaledDynamic.y) {
            state = (scaledDynamic.x < 0) ? .turningRight : .turningLeft
        } else if scaledDynamic.y < -0.06 {
            state = .accelerating
        } else if scaledDynamic.y > 0.06 {
            state = .braking
        } else if abs(scaledDynamic.z) > 0.08 {
            state = .turbulence
        } else {
            state = .cruising
        }

        return ProcessedMotion(
            rawAcceleration: raw,
            rawRotationRate: sample.rotationRate,
            dynamicAcceleration: scaledDynamic,
            inertialForce: inertialForce,
            jerk: currentJerk,
            rollAngleRad: rollAngle,
            pitchAngleRad: pitchAngle,
            radialExpansion: radialExp,
            vagalPulse: vagalPulseVal,
            vignetteOpacity: vignetteVal,
            state: state,
            activityLevel: currentActivity,
            fadeOpacity: currentFadeOpacity,
            timestamp: now
        )
    }
}
