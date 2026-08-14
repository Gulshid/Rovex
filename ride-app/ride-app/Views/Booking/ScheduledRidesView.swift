//
//  ScheduledRidesView.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (Scheduled Rides)
//
//  A rider's upcoming scheduled rides (RideService.fetchScheduledRides),
//  soonest first, with a Cancel action per row. No pagination — scheduled
//  rides are a small, self-limiting list (nobody schedules hundreds of
//  future rides), unlike Phase 12's full ride history.
//
//  UPDATED in Phase 15 — swapped the plain ProgressView spinner and
//  hand-rolled empty state for the shared RideRowSkeletonList/
//  EmptyStateView components (see Views/Components).
//

import SwiftUI

@MainActor
final class ScheduledRidesViewModel: ObservableObject {

    @Published private(set) var rides: [Ride] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let rideService = RideService.shared

    func load(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            rides = try await rideService.fetchScheduledRides(forRiderId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel(rideId: String, uid: String) async {
        do {
            try await rideService.cancelScheduledRide(rideId: rideId)
            rides.removeAll { $0.id == rideId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ScheduledRidesView: View {

    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = ScheduledRidesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rides.isEmpty {
                ScrollView { RideRowSkeletonList(rowCount: 3) }
            } else if viewModel.rides.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .animation(Theme.AnimationToken.statusChange, value: viewModel.isLoading)
        .navigationTitle("Scheduled Rides")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = sessionManager.currentUser?.id {
                await viewModel.load(uid: uid)
            }
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
                VStack(alignment: .leading, spacing: 6) {
                    if let date = ride.scheduledFor?.dateValue() {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(ride.pickupLocation.address)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(ride.dropoffLocation.address)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .swipeActions {
                    Button("Cancel", role: .destructive) {
                        if let uid = sessionManager.currentUser?.id, let rideId = ride.id {
                            Task { await viewModel.cancel(rideId: rideId, uid: uid) }
                        }
                    }
                }
            }
        }
        .refreshable {
            if let uid = sessionManager.currentUser?.id {
                await viewModel.load(uid: uid)
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: "No scheduled rides",
            message: "Book a ride and choose \"Schedule for Later\" to plan ahead."
        )
    }
}

#Preview {
    NavigationStack { ScheduledRidesView() }
        .environmentObject(SessionManager())
}
