import SwiftUI

/// Compact, polished Menu Bar Popover for instant vehicle motion control
public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var onOpenDiagnostics: () -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    public init(
        appState: AppState,
        onOpenDiagnostics: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onOpenDiagnostics = onOpenDiagnostics
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Title & Toggle
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(MacDotsTheme.cyanAccent.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MacDotsTheme.cyanAccent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("MacDots")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Kinetic Motion Cues")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $appState.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // Live State & Mini Telemetry Card
            GlassCard(padding: 10) {
                HStack(spacing: 12) {
                    // Mini live G-Meter dial
                    GMeterView(
                        acceleration: appState.latestMotion.dynamicAcceleration,
                        inertialForce: appState.latestMotion.inertialForce
                    )
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(appState.isEnabled ? (appState.latestMotion.fadeOpacity > 0.1 ? Color.green : Color.orange) : Color.gray)
                                .frame(width: 7, height: 7)

                            Text(appState.isEnabled ? appState.latestMotion.state.rawValue : "Disabled")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }

                        Text(appState.sensorSource == .hardwareIMU ? "Apple Silicon IMU (100 Hz)" : appState.vehicleProfile.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if appState.latestMotion.activityLevel > 0.04 {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%+.2fg", appState.latestMotion.dynamicAcceleration.magnitude2D))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(MacDotsTheme.cyanAccent)
                            Text("Inertia")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Sensor Mode Segmented Control
            VStack(alignment: .leading, spacing: 6) {
                Text("INPUT SOURCE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $appState.sensorSource) {
                    Text("Hardware IMU").tag(SensorSourceType.hardwareIMU)
                    Text("Simulator").tag(SensorSourceType.simulator)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            // Vehicle Simulator Profiles (if simulator active)
            if appState.sensorSource == .simulator {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEHICLE PROFILE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    Picker("", selection: $appState.vehicleProfile) {
                        ForEach(VehicleProfile.allCases) { profile in
                            Label(profile.rawValue, systemImage: profile.icon).tag(profile)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }

            // Sensitivity Slider
            TactileSlider(
                title: "Sensitivity",
                icon: "slider.horizontal.3",
                value: $appState.sensitivity,
                range: 0.4...2.5,
                step: 0.1,
                displayFormat: "%.1fx"
            )

            // Theme Swatches
            VStack(alignment: .leading, spacing: 4) {
                Text("THEME")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(DotTheme.allCases) { theme in
                        Button {
                            appState.theme = theme
                        } label: {
                            Circle()
                                .fill(theme.primaryColor)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(appState.theme == theme ? MacDotsTheme.cyanAccent : Color.clear, lineWidth: 2)
                                        .padding(-3)
                                )
                                .shadow(color: theme.glowColor, radius: 2)
                        }
                        .buttonStyle(.plain)
                        .help(theme.rawValue)
                    }
                }
                .padding(.top, 2)
            }

            Divider()

            // Footer Navigation Actions
            VStack(spacing: 6) {
                Button(action: onOpenDiagnostics) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(MacDotsTheme.cyanAccent)
                        Text("Live Telemetry & Diagnostics...")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button(action: onOpenSettings) {
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                        Text("Preferences & Research...")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Divider()

                Button(action: onQuit) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit MacDots")
                        Spacer()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 290)
    }
}
