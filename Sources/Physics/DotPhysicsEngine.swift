import Foundation
import CoreGraphics

/// Layout configuration for motion dots
public enum DotLayoutPattern: String, CaseIterable, Identifiable, Codable, Sendable {
    case perimeter = "All Edges (Apple Style)"
    case lateralColumns = "Sides Only (Code / Reading)"
    case horizontalRails = "Top & Bottom Rails"
    case corners = "Corners & Borders"

    public var id: String { rawValue }
}

/// Dot density presets
public enum DotDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case sparse = "Sparse (14 dots)"
    case standard = "Standard (26 dots)"
    case dense = "Dense (44 dots)"
    case ultra = "Ultra (64 dots)"

    public var id: String { rawValue }

    public var count: Int {
        switch self {
        case .sparse: return 14
        case .standard: return 26
        case .dense: return 44
        case .ultra: return 64
        }
    }
}

/// Spring-mass-damper physics engine simulating inertial particles with horizon tilt and 3D optic flow
public final class DotPhysicsEngine: @unchecked Sendable {
    // Physics parameters
    public var stiffness: Double = 22.0          // Spring constant k
    public var dampingRatio: Double = 0.88       // Viscous damping ratio
    public var forceScale: Double = 320.0        // Pixels of displacement per G
    public var maxDisplacement: Double = 90.0    // Soft boundary limit
    public var edgeInset: Double = 32.0          // Resting margin from display edge

    public private(set) var particles: [DotParticle] = []
    public private(set) var screenSize: CGSize = .zero

    private var layoutPattern: DotLayoutPattern = .perimeter
    private var density: DotDensity = .standard
    private var lock = os_unfair_lock()

    public init() {}

    public func configure(screenSize: CGSize, layout: DotLayoutPattern, density: DotDensity, edgeInset: Double = 32.0) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard screenSize.width > 100, screenSize.height > 100 else { return }
        self.screenSize = screenSize
        self.layoutPattern = layout
        self.density = density
        self.edgeInset = edgeInset

        self.particles = generateParticles(size: screenSize, layout: layout, density: density, margin: edgeInset)
    }

    private func generateParticles(size: CGSize, layout: DotLayoutPattern, density: DotDensity, margin: Double) -> [DotParticle] {
        var dots: [DotParticle] = []
        var nextId = 0

        let totalDots = density.count
        let w = Double(size.width)
        let h = Double(size.height)

        switch layout {
        case .perimeter:
            let sideDots = max(4, Int(Double(totalDots) * 0.35))
            let horizontalDots = max(2, (totalDots - 2 * sideDots) / 2)

            // Left edge
            for i in 0..<sideDots {
                let frac = Double(i + 1) / Double(sideDots + 1)
                let y = margin + frac * (h - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .left, anchorX: margin, anchorY: y, mass: 1.0 + Double(i % 3) * 0.05))
                nextId += 1
            }

            // Right edge
            for i in 0..<sideDots {
                let frac = Double(i + 1) / Double(sideDots + 1)
                let y = margin + frac * (h - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .right, anchorX: w - margin, anchorY: y, mass: 1.0 + Double(i % 3) * 0.05))
                nextId += 1
            }

            // Top edge
            for i in 0..<horizontalDots {
                let frac = Double(i + 1) / Double(horizontalDots + 1)
                let x = margin + frac * (w - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .top, anchorX: x, anchorY: h - margin, mass: 1.0 + Double(i % 2) * 0.05))
                nextId += 1
            }

            // Bottom edge
            for i in 0..<horizontalDots {
                let frac = Double(i + 1) / Double(horizontalDots + 1)
                let x = margin + frac * (w - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .bottom, anchorX: x, anchorY: margin, mass: 1.0 + Double(i % 2) * 0.05))
                nextId += 1
            }

        case .lateralColumns:
            let sideCount = totalDots / 2
            for i in 0..<sideCount {
                let frac = Double(i + 1) / Double(sideCount + 1)
                let y = margin + frac * (h - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .left, anchorX: margin, anchorY: y))
                nextId += 1
                dots.append(DotParticle(id: nextId, edge: .right, anchorX: w - margin, anchorY: y))
                nextId += 1
            }

        case .horizontalRails:
            let railCount = totalDots / 2
            for i in 0..<railCount {
                let frac = Double(i + 1) / Double(railCount + 1)
                let x = margin + frac * (w - 2 * margin)
                dots.append(DotParticle(id: nextId, edge: .top, anchorX: x, anchorY: h - margin))
                nextId += 1
                dots.append(DotParticle(id: nextId, edge: .bottom, anchorX: x, anchorY: margin))
                nextId += 1
            }

        case .corners:
            let perCorner = max(3, totalDots / 4)
            let offsets: [(Double, Double, ScreenEdge)] = [
                (margin, margin, .bottom),
                (w - margin, margin, .bottom),
                (margin, h - margin, .top),
                (w - margin, h - margin, .top)
            ]
            for (cx, cy, edge) in offsets {
                for i in 0..<perCorner {
                    let ox = (cx < w / 2) ? Double(i * 24) : -Double(i * 24)
                    let oy = (cy < h / 2) ? Double(i * 24) : -Double(i * 24)
                    dots.append(DotParticle(id: nextId, edge: edge, anchorX: cx + ox, anchorY: cy + oy))
                    nextId += 1
                }
            }
        }

        return dots
    }

    /// Step simulation forward by dt
    public func update(motion: ProcessedMotion, dt: Double) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard dt > 0.0001, !particles.isEmpty else { return }
        let clampedDt = min(0.05, dt)

        let centerX = Double(screenSize.width) / 2.0
        let centerY = Double(screenSize.height) / 2.0

        // External inertial force vector
        let extForceX = motion.inertialForce.x * forceScale
        let extForceY = motion.inertialForce.y * forceScale

        // Damping coefficient c = 2 * dampingRatio * sqrt(k * m)
        let c = 2.0 * dampingRatio * sqrt(stiffness)

        // Horizon roll tilt
        let sinRoll = sin(motion.rollAngleRad)

        for i in 0..<particles.count {
            var p = particles[i]

            // Dynamic anchor calculation with Horizon Tilt and Radial Expansion
            var targetAnchorX = p.anchorX
            var targetAnchorY = p.anchorY

            // 1. Radial Optic Flow Expansion
            if motion.radialExpansion != 1.0 {
                let dxCenter = targetAnchorX - centerX
                let dyCenter = targetAnchorY - centerY
                targetAnchorX = centerX + dxCenter * motion.radialExpansion
                targetAnchorY = centerY + dyCenter * motion.radialExpansion
            }

            // 2. Artificial Horizon Roll Tilt for horizontal edges
            if abs(motion.rollAngleRad) > 0.005 && (p.edge == .top || p.edge == .bottom) {
                let dxCenter = targetAnchorX - centerX
                let tiltOffsetY = dxCenter * sinRoll * 0.45
                targetAnchorY += tiltOffsetY
            }

            // Restoring spring force F_spring = -k * (x - x_anchor)
            let dx = p.currentX - targetAnchorX
            let dy = p.currentY - targetAnchorY

            let fSpringX = -stiffness * dx
            let fSpringY = -stiffness * dy

            // Viscous damping force
            let fDampX = -c * p.vx
            let fDampY = -c * p.vy

            let totalFx = extForceX + fSpringX + fDampX
            let totalFy = extForceY + fSpringY + fDampY

            let ax = totalFx / p.mass
            let ay = totalFy / p.mass

            p.vx += ax * clampedDt
            p.vy += ay * clampedDt

            p.currentX += p.vx * clampedDt
            p.currentY += p.vy * clampedDt

            // Soft non-linear boundary clamp
            let currentDist = sqrt(dx * dx + dy * dy)
            if currentDist > maxDisplacement {
                let excess = currentDist - maxDisplacement
                let normalX = dx / currentDist
                let normalY = dy / currentDist

                p.currentX -= normalX * excess * 0.5
                p.currentY -= normalY * excess * 0.5
                p.vx *= 0.8
                p.vy *= 0.8
            }

            particles[i] = p
        }
    }

    public func getParticles() -> [DotParticle] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return particles
    }
}
