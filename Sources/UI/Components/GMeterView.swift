import SwiftUI

/// 2D Circular Aviation-style G-Meter crosshair display
public struct GMeterView: View {
    public let acceleration: Vector3
    public let inertialForce: Vector3

    public init(acceleration: Vector3, inertialForce: Vector3) {
        self.acceleration = acceleration
        self.inertialForce = inertialForce
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2.0
            let center = CGPoint(x: geo.size.width / 2.0, y: geo.size.height / 2.0)

            ZStack {
                // Background dial
                Circle()
                    .fill(Color.black.opacity(0.3))

                // Concentric circles (0.2g, 0.4g, 0.6g)
                ForEach([0.33, 0.66, 1.0], id: \.self) { fraction in
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: size * fraction, height: size * fraction)
                }

                // Axis crosshairs
                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - radius))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                    path.move(to: CGPoint(x: center.x - radius, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                // Vector trail
                let maxG = 0.5 // Outer ring is 0.5g
                let targetX = center.x + CGFloat(inertialForce.x / maxG) * radius
                let targetY = center.y + CGFloat(inertialForce.y / maxG) * radius

                // Inertial force vector line
                Path { path in
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: targetX, y: targetY))
                }
                .stroke(Color.cyan.opacity(0.7), lineWidth: 2)

                // Puck / dot
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.cyan.opacity(0.8), radius: 4)
                    .position(x: targetX, y: targetY)
            }
        }
    }
}
