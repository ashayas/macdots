import SwiftUI

/// Cohesive design system for MacDots
public enum MacDotsTheme {
    public static let cyanAccent = Color(red: 0.05, green: 0.75, blue: 1.0)
    public static let emeraldAccent = Color(red: 0.15, green: 0.90, blue: 0.45)
    public static let amberAccent = Color(red: 1.0, green: 0.65, blue: 0.15)
    public static let darkCardBackground = Color(white: 0.12, opacity: 0.75)
    public static let lightCardBackground = Color(white: 0.96, opacity: 0.75)

    public static let cornerRadiusLarge: CGFloat = 14.0
    public static let cornerRadiusMedium: CGFloat = 10.0
    public static let cornerRadiusSmall: CGFloat = 6.0
}

/// Glassmorphic Card Container with subtle border and material backdrop
public struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat

    public init(padding: CGFloat = 12.0, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .cornerRadius(MacDotsTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: MacDotsTheme.cornerRadiusMedium)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

/// Sleek capsule status pill showing live state
public struct StatusPill: View {
    public let title: String
    public let icon: String
    public let color: Color
    public var pulse: Bool = false

    public init(title: String, icon: String, color: Color, pulse: Bool = false) {
        self.title = title
        self.icon = icon
        self.color = color
        self.pulse = pulse
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: pulse ? color.opacity(0.9) : .clear, radius: 4)

            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(12)
        .overlay(
            Capsule()
                .stroke(color.opacity(0.25), lineWidth: 0.8)
        )
    }
}

/// Tactile slider with real-time value badge
public struct TactileSlider: View {
    public let title: String
    public let icon: String?
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public let displayFormat: String

    public init(
        title: String,
        icon: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.1,
        displayFormat: String = "%.1f"
    ) {
        self.title = title
        self.icon = icon
        self._value = value
        self.range = range
        self.step = step
        self.displayFormat = displayFormat
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: displayFormat, value))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(MacDotsTheme.cyanAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(MacDotsTheme.cyanAccent.opacity(0.12))
                    .cornerRadius(4)
            }
            Slider(value: $value, in: range, step: step)
                .controlSize(.small)
        }
    }
}
