import SwiftUI

enum MessengerTheme {
    static let cornerLarge: CGFloat = 24
    static let cornerMedium: CGFloat = 16
    static let cornerSmall: CGFloat = 12

    static let bubbleShadow = Color.black.opacity(0.08)
    static let divider = Color.dynamic(
        light: UIColor.systemGray4.withAlphaComponent(0.55),
        dark: UIColor.systemGray3.withAlphaComponent(0.20)
    )

    static let appBackground = Color.dynamic(
        light: UIColor(red: 0.95, green: 0.97, blue: 0.965, alpha: 1.0),
        dark: UIColor(red: 0.10, green: 0.115, blue: 0.12, alpha: 1.0)
    )

    static let elevatedBackground = Color.dynamic(
        light: UIColor.white.withAlphaComponent(0.82),
        dark: UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 0.86)
    )

    static let secondarySurface = Color.dynamic(
        light: UIColor.systemGray6.withAlphaComponent(0.72),
        dark: UIColor.white.withAlphaComponent(0.06)
    )

    static let incomingBubble = Color.dynamic(
        light: UIColor.systemGray5.withAlphaComponent(0.72),
        dark: UIColor.white.withAlphaComponent(0.085)
    )

    static let accent = Color.dynamic(
        light: UIColor(red: 0.85, green: 0.48, blue: 0.36, alpha: 1.0),
        dark: UIColor(red: 0.72, green: 0.36, blue: 0.23, alpha: 1.0)
    )

    static let accentSoft = Color.dynamic(
        light: UIColor(red: 0.96, green: 0.87, blue: 0.82, alpha: 1.0),
        dark: UIColor(red: 0.30, green: 0.20, blue: 0.17, alpha: 1.0)
    )

    static let selfBubbleGradient = LinearGradient(
        colors: [
            Color.dynamic(
                light: UIColor(red: 0.17, green: 0.43, blue: 0.43, alpha: 1.0),
                dark: UIColor(red: 0.13, green: 0.28, blue: 0.28, alpha: 1.0)
            ),
            Color.dynamic(
                light: UIColor(red: 0.12, green: 0.29, blue: 0.29, alpha: 1.0),
                dark: UIColor(red: 0.09, green: 0.20, blue: 0.20, alpha: 1.0)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension View {
    func messengerCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .background(MessengerTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: MessengerTheme.cornerMedium, style: .continuous))
    }

    func messengerStroke() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: MessengerTheme.cornerMedium, style: .continuous)
                .stroke(MessengerTheme.divider, lineWidth: 0.8)
        )
    }

    func messengerBackground() -> some View {
        self.background(
            ZStack {
                MessengerTheme.appBackground
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.clear,
                        MessengerTheme.accent.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
    }
}

extension Font {
    static let messageMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let messageTime = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let daySeparator = Font.system(size: 12, weight: .semibold, design: .rounded)
}

extension DateFormatter {
    static let messengerTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let messengerDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

extension Date {
    var messengerTimeString: String {
        DateFormatter.messengerTime.string(from: self)
    }

    var messengerDayString: String {
        if Calendar.current.isDateInToday(self) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(self) { return "Вчера" }
        return DateFormatter.messengerDay.string(from: self)
    }
}
