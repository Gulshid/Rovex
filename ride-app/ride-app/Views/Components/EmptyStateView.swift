//
//  EmptyStateView.swift
//  RideBookingApp
//
//  Phase 15 — UI Polish, Dark Mode, Animations, Accessibility
//
//  A consistent empty-state layout (icon + title + message) — several
//  screens (RideHistoryView, ScheduledRidesView, DriverService's
//  "no nearby rides" case) previously each hand-rolled their own near-
//  identical VStack. Centralizing it means new empty states are one line
//  and automatically get VoiceOver grouping (a screen reader announces
//  the icon/title/message as one element instead of three).
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        icon: "clock.arrow.circlepath",
        title: "No rides yet",
        message: "Your past rides will show up here."
    )
}
