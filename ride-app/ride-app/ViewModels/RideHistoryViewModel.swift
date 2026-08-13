//
//  RideHistoryViewModel.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Paginated list of a user's past rides (Firestore query cursors via
//  RideService.fetchRideHistoryPage). Riders see rides where they're
//  `riderId`, drivers see rides where they're `driverId`. `configure` is
//  called once by RideHistoryView after SessionManager resolves the
//  current user's role, rather than passed into init — this keeps
//  RideHistoryView's own init parameterless so Router.destination(for:)
//  doesn't need to know the role itself (it's a plain enum-driven method,
//  not a View, so it can't read @EnvironmentObject).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class RideHistoryViewModel: ObservableObject {

    @Published private(set) var rides: [Ride] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?

    private let rideService = RideService.shared
    private var lastDocument: DocumentSnapshot?
    private var field = "riderId"
    private var hasConfigured = false
    private let pageSize = 20

    func configure(isDriver: Bool) {
        guard !hasConfigured else { return }
        hasConfigured = true
        field = isDriver ? "driverId" : "riderId"
    }

    func loadInitial() async {
        guard let uid = Auth.auth().currentUser?.uid, rides.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await fetchPage(uid: uid)
    }

    /// Called from each row's `.task` — fetches the next page once the
    /// user scrolls within 5 rows of the end of what's currently loaded.
    func loadMoreIfNeeded(currentItem ride: Ride) async {
        guard hasMore, !isLoadingMore else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let index = rides.firstIndex(where: { $0.id == ride.id }),
              index >= rides.count - 5 else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchPage(uid: uid)
    }

    func refresh() async {
        rides = []
        lastDocument = nil
        hasMore = true
        await loadInitial()
    }

    private func fetchPage(uid: String) async {
        do {
            let (page, last) = try await rideService.fetchRideHistoryPage(
                forUserId: uid,
                field: field,
                pageSize: pageSize,
                after: lastDocument
            )
            rides.append(contentsOf: page)
            lastDocument = last
            hasMore = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
