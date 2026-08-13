//
//  RideDetailView.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Replaces Router's old `.rideDetail` placeholder Text. Full read-only
//  summary of one past ride — route, fare receipt if completed, and the
//  other participant's info — reusing the same Ride/FareBreakdown models
//  as the live booking flow. Offers a "Rate Driver"/"Rate Rider" button
//  if the current user hasn't already rated this ride.
//

import SwiftUI
import FirebaseAuth

@MainActor
final class RideDetailViewModel: ObservableObject {

    let rideId: String

    @Published private(set) var ride: Ride?
    @Published private(set) var otherUser: AppUser?
    @Published private(set) var hasRated = false
    @Published var errorMessage: String?

    private let rideService = RideService.shared
    private let userService = UserService.shared
    private let ratingService = RatingService.shared

    init(rideId: String) {
        self.rideId = rideId
    }

    func load() async {
        do {
            let ride = try await rideService.fetchRide(rideId: rideId)
            self.ride = ride

            guard let uid = Auth.auth().currentUser?.uid else { return }
            let otherId = (ride.riderId == uid) ? ride.driverId : ride.riderId
            if let otherId {
                otherUser = try? await userService.fetchUser(uid: otherId)
            }
            hasRated = (try? await ratingService.hasRated(rideId: rideId, fromUserId: uid)) ?? false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RideDetailView: View {

    @StateObject private var viewModel: RideDetailViewModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var sessionManager: SessionManager

    init(rideId: String) {
        _viewModel = StateObject(wrappedValue: RideDetailViewModel(rideId: rideId))
    }

    private var isDriver: Bool {
        sessionManager.currentUser?.role == .driver
    }

    var body: some View {
        Group {
            if let ride = viewModel.ride {
                content(ride)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
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

    private func content(_ ride: Ride) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                statusHeader(ride)
                otherUserCard
                routeCard(ride)
                if let fare = ride.fare {
                    receiptCard(fare)
                }
                if ride.status == .completed, !viewModel.hasRated, let otherId = otherUserId(ride), let rideId = ride.id {
                    Button("Rate \(isDriver ? "Rider" : "Driver")") {
                        router.push(.rateRide(rideId: rideId, ratedUserId: otherId, isDriver: isDriver))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }

    private func otherUserId(_ ride: Ride) -> String? {
        isDriver ? ride.riderId : ride.driverId
    }

    private func statusHeader(_ ride: Ride) -> some View {
        VStack(spacing: 6) {
            Text(ride.status.rawValue.capitalized)
                .font(.title2.bold())
            if let date = ride.createdAt?.dateValue() {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var otherUserCard: some View {
        Group {
            if let user = viewModel.otherUser {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: user.photoURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name).font(.body.weight(.semibold))
                        if let rating = user.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func routeCard(_ ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(ride.pickupLocation.address, systemImage: "circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Label(ride.dropoffLocation.address, systemImage: "mappin")
                .foregroundStyle(.red)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func receiptCard(_ fare: FareBreakdown) -> some View {
        VStack(spacing: 0) {
            row("Base fare", fare.baseFare)
            Divider()
            row("Distance (\(String(format: "%.1f", fare.distanceKm)) km)", fare.distanceFare)
            Divider()
            row("Time (\(String(format: "%.0f", fare.durationMin)) min)", fare.timeFare)
            Divider()
            HStack {
                Text("Total").font(.body.weight(.semibold))
                Spacer()
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", fare.total))")
                    .font(.body.weight(.semibold))
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", value))")
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        RideDetailView(rideId: "preview-ride-id")
            .environmentObject(Router())
            .environmentObject(SessionManager())
    }
}
