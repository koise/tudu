import SwiftUI

enum AppTheme {

    // MARK: Colors
    enum Color {
        static let accent       = SwiftUI.Color.indigo
        static let surface      = SwiftUI.Color(.secondarySystemBackground)
        static let surfaceRaised = SwiftUI.Color(.systemBackground)
        static let destructive  = SwiftUI.Color.red
        static let muted        = SwiftUI.Color(.tertiaryLabel)
        static let success      = SwiftUI.Color.mint
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 18
        static let pill: CGFloat = 100
    }

    // MARK: Spacing
    enum Space {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    // MARK: Typography helpers
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
