import Foundation

/// 2nd-Order Direct Form II Transposed Biquad IIR Filter
/// Used for smooth, phase-controlled filtering of motion sensor signals.
public struct BiquadFilter: Sendable {
    // Coefficients
    private var b0: Double = 1.0
    private var b1: Double = 0.0
    private var b2: Double = 0.0
    private var a1: Double = 0.0
    private var a2: Double = 0.0

    // Direct form II transposed delay registers
    private var z1: Double = 0.0
    private var z2: Double = 0.0

    public init() {}

    /// Configures a 2nd-order Butterworth Low-Pass Filter
    /// - Parameters:
    ///   - cutoffHz: Cutoff frequency (-3dB point) in Hertz (e.g. 2.0 Hz)
    ///   - sampleRateHz: Sampling rate in Hertz (e.g. 100 Hz for IMU, 60 Hz for simulator)
    ///   - q: Quality factor (default 0.7071 for maximally flat Butterworth response)
    public static func lowPass(cutoffHz: Double, sampleRateHz: Double, q: Double = 0.70710678) -> BiquadFilter {
        var filter = BiquadFilter()
        guard cutoffHz > 0, sampleRateHz > 0, cutoffHz < sampleRateHz * 0.49 else { return filter }

        let omega = 2.0 * .pi * (cutoffHz / sampleRateHz)
        let alpha = sin(omega) / (2.0 * q)
        let cosOmega = cos(omega)

        let a0 = 1.0 + alpha
        filter.b0 = ((1.0 - cosOmega) / 2.0) / a0
        filter.b1 = (1.0 - cosOmega) / a0
        filter.b2 = ((1.0 - cosOmega) / 2.0) / a0
        filter.a1 = (-2.0 * cosOmega) / a0
        filter.a2 = (1.0 - alpha) / a0

        return filter
    }

    /// Configures a 2nd-order Butterworth High-Pass Filter
    public static func highPass(cutoffHz: Double, sampleRateHz: Double, q: Double = 0.70710678) -> BiquadFilter {
        var filter = BiquadFilter()
        guard cutoffHz > 0, sampleRateHz > 0, cutoffHz < sampleRateHz * 0.49 else { return filter }

        let omega = 2.0 * .pi * (cutoffHz / sampleRateHz)
        let alpha = sin(omega) / (2.0 * q)
        let cosOmega = cos(omega)

        let a0 = 1.0 + alpha
        filter.b0 = ((1.0 + cosOmega) / 2.0) / a0
        filter.b1 = (-(1.0 + cosOmega)) / a0
        filter.b2 = ((1.0 + cosOmega) / 2.0) / a0
        filter.a1 = (-2.0 * cosOmega) / a0
        filter.a2 = (1.0 - alpha) / a0

        return filter
    }

    /// Process a single incoming sample
    public mutating func process(_ input: Double) -> Double {
        let output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }

    /// Reset filter memory
    public mutating func reset() {
        z1 = 0.0
        z2 = 0.0
    }
}

/// 3-Axis Biquad Filter bank
public struct Vector3BiquadFilter: Sendable {
    public var xFilter: BiquadFilter
    public var yFilter: BiquadFilter
    public var zFilter: BiquadFilter

    public init(cutoffHz: Double, sampleRateHz: Double, isHighPass: Bool = false) {
        if isHighPass {
            self.xFilter = BiquadFilter.highPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
            self.yFilter = BiquadFilter.highPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
            self.zFilter = BiquadFilter.highPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
        } else {
            self.xFilter = BiquadFilter.lowPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
            self.yFilter = BiquadFilter.lowPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
            self.zFilter = BiquadFilter.lowPass(cutoffHz: cutoffHz, sampleRateHz: sampleRateHz)
        }
    }

    public mutating func process(_ v: Vector3) -> Vector3 {
        Vector3(
            x: xFilter.process(v.x),
            y: yFilter.process(v.y),
            z: zFilter.process(v.z)
        )
    }

    public mutating func reset() {
        xFilter.reset()
        yFilter.reset()
        zFilter.reset()
    }
}
