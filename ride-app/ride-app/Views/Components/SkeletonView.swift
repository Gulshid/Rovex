//
//  SkeletonView.swift
//  RideBookingApp
//
//  Phase 15 — UI Polish, Dark Mode, Animations, Accessibility
//
//  A subtle shimmering placeholder shown instead of a blank screen while
//  data loads — used first on RideHistoryView's initial load, but generic
//  enough to drop into any list-shaped loading state. Uses semantic
//  Color(.secondarySystemBackground)/.systemBackground so the shimmer
//  reads correctly in both Light and Dark Mode without any special-casing.
//

import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = Theme.Radius.chip

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                LinearGradient(
                    colors: [.clear, Color(.systemBackground).opacity(0.5), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(20))
                .offset(x: isAnimating ? 300 : -300)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A skeleton shaped like a RideHistoryRow, repeated a few times — drop
/// in wherever a list of that shape is loading for the first time.
struct RideRowSkeletonList: View {
    var rowCount: Int = 6

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(0..<rowCount, id: \.self) { _ in
                HStack(spacing: Theme.Spacing.md) {
                    SkeletonView(cornerRadius: 16)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView().frame(height: 14).frame(maxWidth: .infinity)
                        SkeletonView().frame(width: 140, height: 10)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    RideRowSkeletonList()
}
