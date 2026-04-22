import SwiftUI

extension DesignTokens.Size {
    static let groupCardAvatarSize: CGFloat = 40
    static let bridgeLogDetailFontDefault: CGFloat = 17
    static let bridgeLogDetailFontMin: CGFloat = 10
    static let bridgeLogDetailFontMax: CGFloat = 28
}

extension DesignTokens {
    nonisolated enum JSONSyntax {
        static let key = adaptive(
            light: UIColor(red: 0.45, green: 0.18, blue: 0.55, alpha: 1),
            dark:  UIColor(red: 0.82, green: 0.62, blue: 0.95, alpha: 1)
        )
        static let string = adaptive(
            light: UIColor(red: 0.70, green: 0.15, blue: 0.20, alpha: 1),
            dark:  UIColor(red: 1.00, green: 0.55, blue: 0.55, alpha: 1)
        )
        static let number = adaptive(
            light: UIColor(red: 0.10, green: 0.40, blue: 0.55, alpha: 1),
            dark:  UIColor(red: 0.55, green: 0.85, blue: 0.95, alpha: 1)
        )
        static let bool = adaptive(
            light: UIColor(red: 0.65, green: 0.40, blue: 0.05, alpha: 1),
            dark:  UIColor(red: 1.00, green: 0.72, blue: 0.35, alpha: 1)
        )
        static let null = adaptive(light: .systemGray, dark: .systemGray2)
        static let punctuation = Color.secondary

        private static func adaptive(light: UIColor, dark: UIColor) -> Color {
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        }
    }
}
