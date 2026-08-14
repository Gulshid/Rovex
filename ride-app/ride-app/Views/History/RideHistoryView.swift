//
//  RideHistoryView.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Replaces Router's old `.rideHistory` placeholder Text. Paginated list
//  (Firestore query cursors, via RideHistoryViewModel) of the current
//  user's past rides — riders and drivers each see their own side of the
//  same `rides` collection, determined from SessionManager's role.
//
//  UPDATED in Phase 15 — swapped the plain ProgressView spinner for
//  RideRowSkeletonList on first load, and the hand-rolled empty-state
//  VStack for the shared EmptyStateView component.
//

import SwiftUI

struct RideHistoryView: View {

    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel = RideHistoryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rides.isEmpty {
                ScrollView { RideRowSkeletonList() }
            } else if viewModel.rides.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .animation(Theme.AnimationToken.statusChange, value: viewModel.isLoading)
        .navigationTitle("Ride History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.configure(isDriver: sessionManager.currentUser?.role == .driver)
            await viewModel.loadInitial()
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.rides) { ride in
                Button {
                    if let id = ride.id {
                        router.push(.rideDetail(rideId: id))
                    }
                } label: {
                    RideHistoryRow(ride: ride)
                }
                .buttonStyle(.plain)
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: ride)
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No rides yet",
            message: "Your past rides will show up here."
        )
    }
}

private struct RideHistoryRow: View {
    let ride: Ride

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(ride.dropoffLocation.address)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(ride.pickupLocation.address)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let date = ride.createdAt?.dateValue() {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let total = ride.fare?.total ?? ride.estimatedFare {
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", total))")
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: String {
        switch ride.status {
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "clock.fill"
        }
    }

    private var statusColor: Color {
        switch ride.status {
        case .completed: return .green
        case .cancelled: return .red
        default: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        RideHistoryView()
            .environmentObject(SessionManager())
            .environmentObject(Router())
    }
}
