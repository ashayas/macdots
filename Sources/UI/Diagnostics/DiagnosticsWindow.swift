import SwiftUI

/// Diagnostics and Live Telemetry Window with Aviation-style HUD styling
public struct DiagnosticsWindowView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacDots Telemetry HUD")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Live sensor kinematics, vestibular-ocular metrics & vehicle state")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                StatusPill(
                    title: appState.isEnabled ? appState.latestMotion.state.rawValue : "Disabled",
                    icon: appState.latestMotion.state.icon,
                    color: appState.isEnabled ? (appState.latestMotion.fadeOpacity > 0.1 ? Color.green : Color.orange) : Color.gray,
                    pulse: appState.latestMotion.activityLevel > 0.1
                )
            }
            .padding(.horizontal)
            .padding(.top, 14)

            Divider()

            // Main Telemetry Row
            HStack(spacing: 16) {
                // Left: 2D G-Meter & Attitude Gauge
                VStack(spacing: 10) {
                    Text("Inertial G-Vector")
                        .font(.system(size: 12, weight: .bold))

                    GMeterView(
                        acceleration: appState.latestMotion.dynamicAcceleration,
                        inertialForce: appState.latestMotion.inertialForce
                    )
                    .frame(width: 140, height: 140)

                    HStack(spacing: 8) {
                        VStack(spacing: 1) {
                            Text("Roll Bank")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(String(format: "%+.1f°", appState.latestMotion.rollAngleRad * 180.0 / .pi))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(MacDotsTheme.cyanAccent)
                        }

                        VStack(spacing: 1) {
                            Text("Fade")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("\(Int(appState.latestMotion.fadeOpacity * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                }
                .frame(width: 170)
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(MacDotsTheme.cornerRadiusMedium)

                // Center: Kinematic Data Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("Kinematics & Research Metrics")
                        .font(.system(size: 12, weight: .bold))

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                        GridRow {
                            Text("Channel").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Text("X (Lateral)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Text("Y (Longitudinal)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Text("Z (Vertical)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                        }

                        Divider()

                        GridRow {
                            Text("Raw Accel:")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(format: "%.3fg", appState.latestMotion.rawAcceleration.x))
                                .font(.system(size: 10, design: .monospaced))
                            Text(String(format: "%.3fg", appState.latestMotion.rawAcceleration.y))
                                .font(.system(size: 10, design: .monospaced))
                            Text(String(format: "%.3fg", appState.latestMotion.rawAcceleration.z))
                                .font(.system(size: 10, design: .monospaced))
                        }

                        GridRow {
                            Text("Filtered G:")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(format: "%+.3fg", appState.latestMotion.dynamicAcceleration.x))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                            Text(String(format: "%+.3fg", appState.latestMotion.dynamicAcceleration.y))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                            Text(String(format: "%+.3fg", appState.latestMotion.dynamicAcceleration.z))
                                .font(.system(size: 10, design: .monospaced))
                        }

                        GridRow {
                            Text("Jerk (da/dt):")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(format: "%+.2fg/s", appState.latestMotion.jerk.x))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                            Text(String(format: "%+.2fg/s", appState.latestMotion.jerk.y))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange)
                            Text(String(format: "%+.2fg/s", appState.latestMotion.jerk.z))
                                .font(.system(size: 10, design: .monospaced))
                        }

                        GridRow {
                            Text("Gyro Rate:")
                                .font(.system(size: 10, weight: .semibold))
                            Text(String(format: "%+.1f°/s", appState.latestMotion.rawRotationRate.x))
                                .font(.system(size: 10, design: .monospaced))
                            Text(String(format: "%+.1f°/s", appState.latestMotion.rawRotationRate.y))
                                .font(.system(size: 10, design: .monospaced))
                            Text(String(format: "%+.1f°/s", appState.latestMotion.rawRotationRate.z))
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Telemetry Stream").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(appState.sensorSource.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Spacer()
                        Button("Re-Level Tilt") {
                            appState.resetCalibration()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(MacDotsTheme.cornerRadiusMedium)
            }
            .padding(.horizontal)

            // Oscilloscope Waveform
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Real-Time Oscilloscope Waveform")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Butterworth 2.2 Hz Low-Pass Filtered")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                WaveformGraph(history: appState.motionHistory, maxSamples: appState.maxHistorySamples)
                    .frame(height: 105)
            }
            .padding(.horizontal)

            // Force Impulse Simulator Triggers
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Kinetic Maneuvers")
                    .font(.system(size: 12, weight: .bold))

                HStack(spacing: 8) {
                    Button("⬅️ Turn Left") {
                        appState.injectImpulse(lateral: 0.28, longitudinal: 0.0)
                    }
                    Button("➡️ Turn Right") {
                        appState.injectImpulse(lateral: -0.28, longitudinal: 0.0)
                    }
                    Button("⬆️ Hard Brake") {
                        appState.injectImpulse(lateral: 0.0, longitudinal: 0.35)
                    }
                    Button("⬇️ Forward Accel") {
                        appState.injectImpulse(lateral: 0.0, longitudinal: -0.25)
                    }
                    Button("🌊 Turbulence") {
                        appState.injectImpulse(lateral: 0.15, longitudinal: 0.15, duration: 1.2)
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.bottom, 14)
        }
        .frame(width: 560, height: 510)
    }
}
