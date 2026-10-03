import Foundation
import SwiftUI
import Combine

/// Color and style theme for motion cue dots
public enum DotTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleSlate = "Apple Slate (Default)"
    case electricCyan = "Electric Cyan"
    case amberGlow = "Amber Night"
    case highContrastWhite = "High-Contrast White"
    case darkMonochrome = "Dark Monochrome"
    case emerald = "Neon Emerald"

    public var id: String { rawValue }

    public var primaryColor: Color {
        switch self {
        case .appleSlate:
            return Color(white: 0.92)
        case .electricCyan:
            return Color(red: 0.15, green: 0.85, blue: 1.0)
        case .amberGlow:
            return Color(red: 1.0, green: 0.65, blue: 0.15)
        case .highContrastWhite:
            return Color.white
        case .darkMonochrome:
            return Color(white: 0.18)
        case .emerald:
            return Color(red: 0.20, green: 0.95, blue: 0.45)
        }
    }

    public var glowColor: Color {
        switch self {
        case .appleSlate:
            return Color.black.opacity(0.35)
        case .electricCyan:
            return Color(red: 0.0, green: 0.75, blue: 1.0).opacity(0.6)
        case .amberGlow:
            return Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.6)
        case .highContrastWhite:
            return Color.black.opacity(0.5)
        case .darkMonochrome:
            return Color.white.opacity(0.4)
        case .emerald:
            return Color(red: 0.0, green: 0.9, blue: 0.3).opacity(0.6)
        }
    }
}

/// Central state and user preferences coordinator
@MainActor
public final class AppState: ObservableObject {
    // App Enablement
    @Published public var isEnabled: Bool = true {
        didSet { savePreferences() }
    }

    // Telemetry Source
    @Published public var sensorSource: SensorSourceType = .hardwareIMU {
        didSet {
            sensorManager.setSource(sensorSource)
            savePreferences()
        }
    }

    @Published public var vehicleProfile: VehicleProfile = .cityBus {
        didSet {
            sensorManager.simulator.setProfile(vehicleProfile)
            savePreferences()
        }
    }

    // Visual Appearance
    @Published public var theme: DotTheme = .appleSlate {
        didSet { savePreferences() }
    }

    @Published public var layoutPattern: DotLayoutPattern = .perimeter {
        didSet {
            reconfigurePhysics()
            savePreferences()
        }
    }

    @Published public var density: DotDensity = .standard {
        didSet {
            reconfigurePhysics()
            savePreferences()
        }
    }

    @Published public var dotSize: Double = 14.0 {
        didSet { savePreferences() }
    }

    @Published public var baseOpacity: Double = 0.85 {
        didSet { savePreferences() }
    }

    @Published public var edgeInset: Double = 34.0 {
        didSet {
            reconfigurePhysics()
            savePreferences()
        }
    }

    @Published public var hasGlow: Bool = true {
        didSet { savePreferences() }
    }

    @Published public var hasTrails: Bool = false {
        didSet { savePreferences() }
    }

    // Advanced Kinetosis Research Enhancements
    @Published public var anticipatoryJerkEnabled: Bool = true {
        didSet {
            processor.anticipatoryJerkEnabled = anticipatoryJerkEnabled
            savePreferences()
        }
    }

    @Published public var horizonTiltEnabled: Bool = true {
        didSet {
            processor.horizonTiltEnabled = horizonTiltEnabled
            savePreferences()
        }
    }

    @Published public var opticFlowDepthEnabled: Bool = true {
        didSet {
            processor.opticFlowDepthEnabled = opticFlowDepthEnabled
            savePreferences()
        }
    }

    @Published public var dynamicVignetteEnabled: Bool = true {
        didSet {
            processor.dynamicVignetteEnabled = dynamicVignetteEnabled
            savePreferences()
        }
    }

    @Published public var vagalCalmingEnabled: Bool = true {
        didSet {
            processor.vagalCalmingEnabled = vagalCalmingEnabled
            savePreferences()
        }
    }

    @Published public var showHorizonGuide: Bool = false {
        didSet { savePreferences() }
    }

    // Privacy & Screen Sharing Protection
    @Published public var hideWhenScreenCaptured: Bool = true {
        didSet {
            savePreferences()
            onVisibilityNeedsUpdate?()
        }
    }

    @Published public var isScreenCaptured: Bool = false {
        didSet {
            onVisibilityNeedsUpdate?()
        }
    }

    public var onVisibilityNeedsUpdate: (@MainActor () -> Void)?
    public let screenCaptureDetector = ScreenCaptureDetector()

    // Physics & Sensation Tuning
    @Published public var sensitivity: Double = 1.0 {
        didSet {
            processor.sensitivity = sensitivity
            savePreferences()
        }
    }

    @Published public var stiffness: Double = 22.0 {
        didSet {
            physicsEngine.stiffness = stiffness
            savePreferences()
        }
    }

    @Published public var damping: Double = 0.88 {
        didSet {
            physicsEngine.dampingRatio = damping
            savePreferences()
        }
    }

    @Published public var autoFade: Bool = true {
        didSet {
            processor.autoFadeEnabled = autoFade
            savePreferences()
        }
    }

    // Live Telemetry Observables
    @Published public var latestMotion: ProcessedMotion = ProcessedMotion(
        rawAcceleration: Vector3(x: 0, y: 0, z: -1),
        rawRotationRate: .zero,
        dynamicAcceleration: .zero,
        inertialForce: .zero,
        jerk: .zero,
        rollAngleRad: 0.0,
        pitchAngleRad: 0.0,
        radialExpansion: 1.0,
        vagalPulse: 0.0,
        vignetteOpacity: 0.0,
        state: .stationary,
        activityLevel: 0.0,
        fadeOpacity: 1.0,
        timestamp: 0
    )

    @Published public var motionHistory: [ProcessedMotion] = []
    public let maxHistorySamples: Int = 120

    // Core Managers
    public let sensorManager = SensorManager()
    public let processor = MotionProcessor()
    public let physicsEngine = DotPhysicsEngine()

    private var lastPhysicsTime: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadPreferences()

        // Sync initial processor and physics settings
        processor.sensitivity = sensitivity
        processor.autoFadeEnabled = autoFade
        processor.anticipatoryJerkEnabled = anticipatoryJerkEnabled
        processor.horizonTiltEnabled = horizonTiltEnabled
        processor.opticFlowDepthEnabled = opticFlowDepthEnabled
        processor.dynamicVignetteEnabled = dynamicVignetteEnabled
        processor.vagalCalmingEnabled = vagalCalmingEnabled

        physicsEngine.stiffness = stiffness
        physicsEngine.dampingRatio = damping

        if !sensorManager.isHardwareAvailable {
            sensorSource = .simulator
        }

        // Real-time screen capture / presentation detection
        screenCaptureDetector.start { [weak self] isCapturing in
            Task { @MainActor in
                self?.isScreenCaptured = isCapturing
            }
        }

        startMotionPipeline()
    }

    public var isHardwareAvailable: Bool {
        sensorManager.isHardwareAvailable
    }

    public func reconfigurePhysics(for screenSize: CGSize? = nil) {
        let size = screenSize ?? physicsEngine.screenSize
        guard size.width > 50, size.height > 50 else { return }
        physicsEngine.configure(
            screenSize: size,
            layout: layoutPattern,
            density: density,
            edgeInset: edgeInset
        )
    }

    private func startMotionPipeline() {
        sensorManager.start { [weak self] sample in
            guard let self = self else { return }
            let processed = self.processor.process(sample: sample)

            Task { @MainActor in
                self.latestMotion = processed
                self.appendHistory(processed)

                let now = processed.timestamp
                let dt = (self.lastPhysicsTime > 0) ? min(0.05, max(0.001, now - self.lastPhysicsTime)) : 0.016
                self.lastPhysicsTime = now

                self.physicsEngine.update(motion: processed, dt: dt)
            }
        }
    }

    private func appendHistory(_ sample: ProcessedMotion) {
        motionHistory.append(sample)
        if motionHistory.count > maxHistorySamples {
            motionHistory.removeFirst(motionHistory.count - maxHistorySamples)
        }
    }

    public func injectImpulse(lateral: Double, longitudinal: Double, duration: TimeInterval = 0.5) {
        sensorManager.simulator.injectImpulse(lateral: lateral, longitudinal: longitudinal, duration: duration)
    }

    public func resetCalibration() {
        processor.resetCalibration()
    }

    // MARK: - Persistence
    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "md_isEnabled")
        defaults.set(sensorSource.rawValue, forKey: "md_sensorSource")
        defaults.set(vehicleProfile.rawValue, forKey: "md_vehicleProfile")
        defaults.set(theme.rawValue, forKey: "md_theme")
        defaults.set(layoutPattern.rawValue, forKey: "md_layoutPattern")
        defaults.set(density.rawValue, forKey: "md_density")
        defaults.set(dotSize, forKey: "md_dotSize")
        defaults.set(baseOpacity, forKey: "md_baseOpacity")
        defaults.set(edgeInset, forKey: "md_edgeInset")
        defaults.set(hasGlow, forKey: "md_hasGlow")
        defaults.set(hasTrails, forKey: "md_hasTrails")
        defaults.set(anticipatoryJerkEnabled, forKey: "md_anticipatoryJerkEnabled")
        defaults.set(horizonTiltEnabled, forKey: "md_horizonTiltEnabled")
        defaults.set(opticFlowDepthEnabled, forKey: "md_opticFlowDepthEnabled")
        defaults.set(dynamicVignetteEnabled, forKey: "md_dynamicVignetteEnabled")
        defaults.set(vagalCalmingEnabled, forKey: "md_vagalCalmingEnabled")
        defaults.set(showHorizonGuide, forKey: "md_showHorizonGuide")
        defaults.set(hideWhenScreenCaptured, forKey: "md_hideWhenScreenCaptured")
        defaults.set(sensitivity, forKey: "md_sensitivity")
        defaults.set(stiffness, forKey: "md_stiffness")
        defaults.set(damping, forKey: "md_damping")
        defaults.set(autoFade, forKey: "md_autoFade")
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "md_isEnabled") != nil {
            isEnabled = defaults.bool(forKey: "md_isEnabled")
        }
        if let s = defaults.string(forKey: "md_sensorSource"), let src = SensorSourceType(rawValue: s) {
            sensorSource = src
        }
        if let s = defaults.string(forKey: "md_vehicleProfile"), let prof = VehicleProfile(rawValue: s) {
            vehicleProfile = prof
        }
        if let s = defaults.string(forKey: "md_theme"), let thm = DotTheme(rawValue: s) {
            theme = thm
        }
        if let s = defaults.string(forKey: "md_layoutPattern"), let lay = DotLayoutPattern(rawValue: s) {
            layoutPattern = lay
        }
        if let s = defaults.string(forKey: "md_density"), let den = DotDensity(rawValue: s) {
            density = den
        }
        if defaults.object(forKey: "md_dotSize") != nil {
            dotSize = defaults.double(forKey: "md_dotSize")
        }
        if defaults.object(forKey: "md_baseOpacity") != nil {
            baseOpacity = defaults.double(forKey: "md_baseOpacity")
        }
        if defaults.object(forKey: "md_edgeInset") != nil {
            edgeInset = defaults.double(forKey: "md_edgeInset")
        }
        if defaults.object(forKey: "md_hasGlow") != nil {
            hasGlow = defaults.bool(forKey: "md_hasGlow")
        }
        if defaults.object(forKey: "md_hasTrails") != nil {
            hasTrails = defaults.bool(forKey: "md_hasTrails")
        }
        if defaults.object(forKey: "md_anticipatoryJerkEnabled") != nil {
            anticipatoryJerkEnabled = defaults.bool(forKey: "md_anticipatoryJerkEnabled")
        }
        if defaults.object(forKey: "md_horizonTiltEnabled") != nil {
            horizonTiltEnabled = defaults.bool(forKey: "md_horizonTiltEnabled")
        }
        if defaults.object(forKey: "md_opticFlowDepthEnabled") != nil {
            opticFlowDepthEnabled = defaults.bool(forKey: "md_opticFlowDepthEnabled")
        }
        if defaults.object(forKey: "md_dynamicVignetteEnabled") != nil {
            dynamicVignetteEnabled = defaults.bool(forKey: "md_dynamicVignetteEnabled")
        }
        if defaults.object(forKey: "md_vagalCalmingEnabled") != nil {
            vagalCalmingEnabled = defaults.bool(forKey: "md_vagalCalmingEnabled")
        }
        if defaults.object(forKey: "md_showHorizonGuide") != nil {
            showHorizonGuide = defaults.bool(forKey: "md_showHorizonGuide")
        }
        if defaults.object(forKey: "md_hideWhenScreenCaptured") != nil {
            hideWhenScreenCaptured = defaults.bool(forKey: "md_hideWhenScreenCaptured")
        }
        if defaults.object(forKey: "md_sensitivity") != nil {
            sensitivity = defaults.double(forKey: "md_sensitivity")
        }
        if defaults.object(forKey: "md_stiffness") != nil {
            stiffness = defaults.double(forKey: "md_stiffness")
        }
        if defaults.object(forKey: "md_damping") != nil {
            damping = defaults.double(forKey: "md_damping")
        }
        if defaults.object(forKey: "md_autoFade") != nil {
            autoFade = defaults.bool(forKey: "md_autoFade")
        }
    }
}
