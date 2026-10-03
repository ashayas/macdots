import SwiftUI

/// Real-time oscilloscope waveform graph showing dynamic motion forces
public struct WaveformGraph: View {
    public let history: [ProcessedMotion]
    public let maxSamples: Int

    public init(history: [ProcessedMotion], maxSamples: Int = 120) {
        self.history = history
        self.maxSamples = maxSamples
    }

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midY = h / 2.0

            // Grid lines
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: 0, y: midY))
            gridPath.addLine(to: CGPoint(x: w, y: midY))

            gridPath.move(to: CGPoint(x: 0, y: midY - h * 0.35))
            gridPath.addLine(to: CGPoint(x: w, y: midY - h * 0.35))

            gridPath.move(to: CGPoint(x: 0, y: midY + h * 0.35))
            gridPath.addLine(to: CGPoint(x: w, y: midY + h * 0.35))

            context.stroke(gridPath, with: .color(Color.gray.opacity(0.2)), lineWidth: 1)

            guard history.count > 1 else { return }

            let step = w / CGFloat(maxSamples - 1)
            let startIndex = max(0, history.count - maxSamples)
            let visible = Array(history[startIndex...])

            // Lateral X path (Red)
            var xPath = Path()
            // Longitudinal Y path (Blue)
            var yPath = Path()

            let scaleY = h * 0.8 // 1.0g = 80% of half-height

            for (i, sample) in visible.enumerated() {
                let px = CGFloat(i) * step
                let ax = sample.dynamicAcceleration.x
                let ay = sample.dynamicAcceleration.y

                let pyX = midY - CGFloat(ax) * scaleY
                let pyY = midY - CGFloat(ay) * scaleY

                if i == 0 {
                    xPath.move(to: CGPoint(x: px, y: pyX))
                    yPath.move(to: CGPoint(x: px, y: pyY))
                } else {
                    xPath.addLine(to: CGPoint(x: px, y: pyX))
                    yPath.addLine(to: CGPoint(x: px, y: pyY))
                }
            }

            // Draw paths
            context.stroke(xPath, with: .color(Color.red.opacity(0.85)), lineWidth: 1.8)
            context.stroke(yPath, with: .color(Color.blue.opacity(0.85)), lineWidth: 1.8)
        }
        .background(Color.black.opacity(0.25))
        .cornerRadius(6)
        .overlay(
            VStack {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("Lateral (Turns)").font(.system(size: 9, weight: .semibold))
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("Longitudinal (Accel/Brake)").font(.system(size: 9, weight: .semibold))
                    }
                    Spacer()
                    Text("±0.5g").font(.system(size: 8, weight: .light)).foregroundColor(.secondary)
                }
                .padding(6)
                Spacer()
            }
        )
    }
}
