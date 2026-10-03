import SwiftUI

/// Preferences and settings window with live interactive visual preview and research toggles
public struct SettingsWindowView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            researchTab
                .tabItem {
                    Label("Clinical Research", systemImage: "brain.head.profile")
                }

            physicsTab
                .tabItem {
                    Label("Physics & Tuning", systemImage: "waveform.path")
                }
        }
        .frame(width: 620, height: 520)
        .padding()
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable MacDots Motion Cues", isOn: $appState.isEnabled)
                    .font(.headline)

                Text("Global Hotkey: ⌃⌥⌘M (Control + Option + Command + M) to quickly toggle cues anywhere.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Motion Sensor Source") {
                Picker("Input Sensor", selection: $appState.sensorSource) {
                    Text("Apple Silicon Hardware IMU").tag(SensorSourceType.hardwareIMU)
                    Text("Vehicle Simulator").tag(SensorSourceType.simulator)
                }
                .pickerStyle(.segmented)

                if appState.sensorSource == .hardwareIMU {
                    HStack {
                        Image(systemName: appState.isHardwareAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(appState.isHardwareAvailable ? .green : .orange)
                        Text(appState.isHardwareAvailable
                             ? "Internal Apple Silicon MEMS IMU active at 100 Hz (Bosch BMI286 via IOKit HID)."
                             : "Hardware IMU not detected. Running simulator fallback.")
                            .font(.caption)
                    }
                } else {
                    Picker("Vehicle Profile", selection: $appState.vehicleProfile) {
                        ForEach(VehicleProfile.allCases) { profile in
                            Label(profile.rawValue, systemImage: profile.icon).tag(profile)
                        }
                    }
                    Text(appState.vehicleProfile.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Idle Energy & Cognitive Behavior") {
                Toggle("Auto-fade dots when vehicle is stationary", isOn: $appState.autoFade)
                Text("Smoothly dims the dots when waiting at traffic signals, bus stops, or holding at the airport gate to minimize visual distraction.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab
    private var appearanceTab: some View {
        Form {
            Section("Live Visual Preview") {
                // Interactive miniature preview of dots
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 120)

                    // Simulated preview dots
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let color = appState.theme.primaryColor
                        let r = appState.dotSize * 0.4

                        // Perimeter preview
                        ForEach(0..<6) { i in
                            let y = 14.0 + Double(i) * ((h - 28.0) / 5.0)
                            // Left
                            Circle().fill(color).frame(width: r * 2, height: r * 2).position(x: 18, y: y)
                            // Right
                            Circle().fill(color).frame(width: r * 2, height: r * 2).position(x: w - 18, y: y)
                        }
                        ForEach(1..<5) { j in
                            let x = Double(j) * (w / 5.0)
                            // Top
                            Circle().fill(color).frame(width: r * 2, height: r * 2).position(x: x, y: 14)
                            // Bottom
                            Circle().fill(color).frame(width: r * 2, height: r * 2).position(x: x, y: h - 14)
                        }
                    }
                    .frame(height: 120)

                    Text("Live Display Preview")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Section("Theme & Layout") {
                Picker("Color Theme", selection: $appState.theme) {
                    ForEach(DotTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                Picker("Layout Pattern", selection: $appState.layoutPattern) {
                    ForEach(DotLayoutPattern.allCases) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }

                Picker("Dot Density", selection: $appState.density) {
                    ForEach(DotDensity.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
            }

            Section("Geometry & Styling") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Dot Size")
                        Spacer()
                        Text("\(Int(appState.dotSize)) pt").foregroundColor(.secondary)
                    }
                    Slider(value: $appState.dotSize, in: 8...26, step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Base Opacity")
                        Spacer()
                        Text("\(Int(appState.baseOpacity * 100))%").foregroundColor(.secondary)
                    }
                    Slider(value: $appState.baseOpacity, in: 0.2...1.0, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Edge Margin")
                        Spacer()
                        Text("\(Int(appState.edgeInset)) pt").foregroundColor(.secondary)
                    }
                    Slider(value: $appState.edgeInset, in: 16...64, step: 2)
                }

                Toggle("Outer Peripheral Glow (Optimized for Retinal Rods)", isOn: $appState.hasGlow)
                Toggle("Velocity Trailing Elongation", isOn: $appState.hasTrails)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Clinical Research Tab
    private var researchTab: some View {
        Form {
            Section("Vestibular-Ocular Scientific Compensations") {
                Toggle("Anticipatory Jerk Feed-Forward (da/dt)", isOn: $appState.anticipatoryJerkEnabled)
                Text("Feeds forward vehicle jerk rate 120ms before full lateral G-force builds up, matching how the brain naturally anticipates driver maneuvers and eliminating visual-vestibular phase lag.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Artificial Horizon Roll Tilt", isOn: $appState.horizonTiltEnabled)
                Text("Tilts edge cues with vehicle banking angle (arctan(ax/g)), providing an unshakeable gravito-inertial horizon reference that eliminates spatial disorientation in turns.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("3D Optic Flow Depth Expansion", isOn: $appState.opticFlowDepthEnabled)
                Text("Expands dots radially toward display corners during forward acceleration and contracts inward during braking, stimulating visual cortex MT/MST vection pathways.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Dynamic Peripheral Anti-Nausea Vignette", isOn: $appState.dynamicVignetteEnabled)
                Text("Softly darkens the outermost 4% of display edges during severe turns (>0.22g) or sudden turbulence, dampening peripheral sensory overload.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Autonomic Vagal Calming Mode", isOn: $appState.vagalCalmingEnabled)
                Text("Gently pulses dots at 0.1 Hz (6 breaths/min) when stopped in traffic to stimulate vagal nerve tone and prevent nausea build-up before the next acceleration.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Show Faint Horizon Reference Guide", isOn: $appState.showHorizonGuide)
                Text("Displays subtle edge ticks aligned with the vehicle's roll axis.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Literature & Clinical Citations") {
                VStack(alignment: .leading, spacing: 6) {
                    citationRow(
                        title: "Sensory Conflict Theory",
                        citation: "Reason, J.T. & Brand, J.J. (1975). Motion Sickness. Academic Press."
                    )
                    citationRow(
                        title: "Evolutionary Toxin Hypothesis",
                        citation: "Treisman, M. (1977). Motion sickness: an evolutionary hypothesis. Science."
                    )
                    citationRow(
                        title: "Kinetosis Resonance Frequencies",
                        citation: "ISO 2631-1 (1997); Griffin, M.J. & Golding, J.F. (2006). Autonomic Neuroscience."
                    )
                    citationRow(
                        title: "Dynamic Peripheral Field Occlusion",
                        citation: "Kunze, K. et al. (2021). Dynamic Peripheral Vision Blocking for Reducing Motion Sickness."
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private func citationRow(title: String, citation: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(MacDotsTheme.cyanAccent)
            Text(citation)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Physics Tab
    private var physicsTab: some View {
        Form {
            Section("Particle Kinematics") {
                TactileSlider(
                    title: "Motion Sensitivity",
                    icon: "speedometer",
                    value: $appState.sensitivity,
                    range: 0.4...2.5,
                    step: 0.1,
                    displayFormat: "%.1fx"
                )

                TactileSlider(
                    title: "Spring Stiffness (k)",
                    icon: "dial.low",
                    value: $appState.stiffness,
                    range: 10...40,
                    step: 1.0,
                    displayFormat: "%.0f"
                )

                TactileSlider(
                    title: "Viscous Damping Ratio (ζ)",
                    icon: "waveform",
                    value: $appState.damping,
                    range: 0.6...1.4,
                    step: 0.02,
                    displayFormat: "%.2f"
                )
            }

            Section("Vibration Filtering") {
                Text("Keystroke typing pulses (15–50 Hz) are rejected by a 2nd-order Butterworth low-pass filter (2.2 Hz cutoff) and an adaptive leaky-integrator gravity tracker.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Reset Physics to Scientific Defaults") {
                    appState.sensitivity = 1.0
                    appState.stiffness = 22.0
                    appState.damping = 0.88
                }
            }
        }
        .formStyle(.grouped)
    }
}
