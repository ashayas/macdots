import Foundation
import CoreGraphics

/// Perimeter edge placement of a dot
public enum ScreenEdge: String, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
}

/// An individual physical particle dot with damped spring dynamics
public struct DotParticle: Identifiable, Sendable {
    public let id: Int
    public let edge: ScreenEdge

    // Rest anchor position on screen (points)
    public var anchorX: Double
    public var anchorY: Double

    // Current dynamic physical position
    public var currentX: Double
    public var currentY: Double

    // Velocity
    public var vx: Double = 0
    public var vy: Double = 0

    // Individual mass/phase jitter for organic fluid appearance
    public var mass: Double = 1.0
    public var phaseOffset: Double = 0.0

    public init(id: Int, edge: ScreenEdge, anchorX: Double, anchorY: Double, mass: Double = 1.0, phaseOffset: Double = 0.0) {
        self.id = id
        self.edge = edge
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.currentX = anchorX
        self.currentY = anchorY
        self.mass = mass
        self.phaseOffset = phaseOffset
    }

    /// Reset position and velocity to resting anchor
    public mutating func resetToAnchor() {
        currentX = anchorX
        currentY = anchorY
        vx = 0
        vy = 0
    }
}
