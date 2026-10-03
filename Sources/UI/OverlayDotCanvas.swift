import SwiftUI

/// High-performance Canvas view rendering animated motion cue dots at native display refresh rates
public struct OverlayDotCanvas: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    guard appState.isEnabled else { return }

                    let motion = appState.latestMotion
                    let effectiveOpacity = appState.baseOpacity * motion.fadeOpacity
                    guard effectiveOpacity > 0.005 else { return }

                    let particles = appState.physicsEngine.getParticles()
                    let dotDiameter = appState.dotSize
                    let dotRadius = dotDiameter / 2.0
                    let theme = appState.theme
                    let primaryColor = theme.primaryColor
                    let glowColor = theme.glowColor

                    // 1. Dynamic Peripheral Anti-Nausea Vignette for Severe Maneuvers
                    if appState.dynamicVignetteEnabled && motion.vignetteOpacity > 0.01 {
                        let vigRect = CGRect(origin: .zero, size: size)
                        let vigAlpha = motion.vignetteOpacity * effectiveOpacity
                        // Subtle soft peripheral border darkening
                        context.stroke(
                            Path(vigRect.insetBy(dx: 12, dy: 12)),
                            with: .color(Color.black.opacity(vigAlpha * 0.45)),
                            lineWidth: 32
                        )
                    }

                    // 2. Subtle Horizon Stabilization Guide (if enabled)
                    if appState.showHorizonGuide && abs(motion.rollAngleRad) > 0.01 {
                        let centerY = size.height / 2.0
                        let halfW = size.width / 2.0
                        let tiltY = halfW * CGFloat(sin(motion.rollAngleRad)) * 0.4

                        var horizonPath = Path()
                        // Left edge tick
                        horizonPath.move(to: CGPoint(x: 8, y: centerY - tiltY))
                        horizonPath.addLine(to: CGPoint(x: 36, y: centerY - tiltY))
                        // Right edge tick
                        horizonPath.move(to: CGPoint(x: size.width - 36, y: centerY + tiltY))
                        horizonPath.addLine(to: CGPoint(x: size.width - 8, y: centerY + tiltY))

                        context.stroke(
                            horizonPath,
                            with: .color(primaryColor.opacity(effectiveOpacity * 0.35)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                        )
                    }

                    // 3. Vagal Calming Breath Pulse (modulation when stationary)
                    let vagalMod = (appState.vagalCalmingEnabled && motion.vagalPulse > 0.0)
                        ? (1.0 + motion.vagalPulse * 0.20)
                        : 1.0

                    // 4. Render Inertial Dots
                    for p in particles {
                        let center = CGPoint(x: p.currentX, y: size.height - p.currentY)

                        let speed = sqrt(p.vx * p.vx + p.vy * p.vy)
                        let speedAlpha = min(1.0, 0.7 + speed / 400.0)

                        // Outer peripheral glow (magnocellular M-cell stimulation)
                        if appState.hasGlow {
                            let glowRadius = dotRadius * 2.2 * vagalMod
                            let glowRect = CGRect(
                                x: center.x - glowRadius,
                                y: center.y - glowRadius,
                                width: glowRadius * 2,
                                height: glowRadius * 2
                            )
                            context.fill(
                                Circle().path(in: glowRect),
                                with: .color(glowColor.opacity(effectiveOpacity * 0.45 * speedAlpha))
                            )
                        }

                        // Velocity Trailing Elongation
                        if appState.hasTrails && speed > 20.0 {
                            let trailLength = min(35.0, speed * 0.08)
                            let angle = atan2(-p.vy, p.vx)
                            let trailEnd = CGPoint(
                                x: center.x - cos(angle) * trailLength,
                                y: center.y - sin(angle) * trailLength
                            )
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: trailEnd)
                            context.stroke(
                                path,
                                with: .color(primaryColor.opacity(effectiveOpacity * 0.4)),
                                lineWidth: dotDiameter * 0.65
                            )
                        }

                        // Crisp Dot Core
                        let currentDiameter = dotDiameter * vagalMod
                        let currentRadius = currentDiameter / 2.0
                        let dotRect = CGRect(
                            x: center.x - currentRadius,
                            y: center.y - currentRadius,
                            width: currentDiameter,
                            height: currentDiameter
                        )

                        // Ambient drop shadow
                        let shadowRect = dotRect.offsetBy(dx: 0, dy: 1.5)
                        context.fill(
                            Circle().path(in: shadowRect),
                            with: .color(Color.black.opacity(effectiveOpacity * 0.35))
                        )

                        // Main fill
                        context.fill(
                            Circle().path(in: dotRect),
                            with: .color(primaryColor.opacity(effectiveOpacity * speedAlpha))
                        )

                        // Specular glass highlight
                        let highlightRect = CGRect(
                            x: center.x - currentRadius * 0.5,
                            y: center.y - currentRadius * 0.7,
                            width: currentDiameter * 0.5,
                            height: currentDiameter * 0.35
                        )
                        context.fill(
                            Ellipse().path(in: highlightRect),
                            with: .color(Color.white.opacity(effectiveOpacity * 0.45))
                        )
                    }
                }
            }
            .onAppear {
                appState.reconfigurePhysics(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                appState.reconfigurePhysics(for: newSize)
            }
        }
        .ignoresSafeArea()
    }
}
