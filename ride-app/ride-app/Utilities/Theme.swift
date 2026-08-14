//
//  Theme.swift
//  RideBookingApp
//
//  Phase 15 — UI Polish, Dark Mode, Animations, Accessibility
//
//  Small, deliberately minimal design-token layer — spacing/radius/
//  animation constants and a couple of semantic color aliases. The app
//  already leans on system semantic colors throughout (Color(.systemBackground),
//  .secondary, etc.), which is what makes Dark Mode support mostly "free"
//  in SwiftUI; this file exists to name the handful of values that were
//  previously inconsistent magic numbers scattered across views (14 vs 16
//  corner radius, 8 vs 10 spacing) so new screens have one obvious place
//  to pull from instead of guessing.
//

import SwiftUI

enum Theme {

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 14
        static let chip: CGFloat = 10
        static let sheet: CGFloat = 20
    }

    enum AnimationToken {
        /// Used for ride-status transitions, map pin drops, and card
        /// appear/disappear — a touch snappier than SwiftUI's default
        /// `.default` spring so status changes feel immediate rather than
        /// sluggish.
        static let statusChange: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    }

    /// Card background — same Color(.secondarySystemBackground) already
    /// used throughout the app, named here so it reads as an intentional
    /// design-system choice rather than a repeated raw call.
    static var cardBackground: Color {
        Color(.secondarySystemBackground)
    }
}

// MARK: - Reusable modifiers

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

extension View {
    /// The rounded, secondary-background card treatment used across
    /// driver cards, receipts, and trip-summary blocks — apply instead of
    /// repeating `.padding().background(...).clipShape(...)` at each
    /// call site.
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
