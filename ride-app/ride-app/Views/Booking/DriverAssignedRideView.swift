//
//  DriverAssignedRideView.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Shown once ride.status is "accepted" or "ongoing" — displays the
//  assigned driver's name/photo/car/plate/rating pulled from Firestore
//  by BookRideViewModel.
//
//  UPDATED in Phase 9 — now embeds LiveRideMapView, showing the driver's
//  marker glide toward pickup (then toward drop-off) as
//  BookRideViewModel.driverLocation updates, plus a live ETA pulled from
//  the same view model.
//
//  UPDATED in Phase 13 — added a "Chat" button next to the driver card,
//  with an unread-message badge (ChatBadgeViewModel) so the rider notices
//  a new message from the driver without having to open chat first.
//
//  UPDATED in Phase 14 — added SOSButton as a floating overlay on the map,
//  visible for the whole active ride.
//

import SwiftUI

struct DriverAssignedRideView: View {

    @ObservedObject var viewModel: BookRideViewModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var chatBadge = ChatBadgeViewModel()

    private var statusText: String {
        viewModel.phase == .ongoing ? "On the way to your destination" : "Your driver is on the way"
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveRideMapView(
                pickupCoordinate: viewModel.pickupCoordinate,
                dropoffCoordinate: viewModel.dropoffCoordinate,
                driverCoordinate: viewModel.driverLocation
            )
            .frame(height: 260)
            .overlay(alignment: .topTrailing) {
                if let uid = sessionManager.currentUser?.id {
                    SOSButton(
                        userName: sessionManager.currentUser?.name ?? "Rider",
                        userId: uid,
                        rideId: viewModel.activeRide?.id,
                        coordinate: viewModel.pickupCoordinate
                    )
                    .padding(12)
                }
            }

            ScrollView {
                VStack(spacing: 20) {
                    Text(statusText)
                        .font(.title3.weight(.semibold))
                        .padding(.top, 20)

                    if let eta = viewModel.etaMinutes {
                        Text("ETA \(Int(eta.rounded())) min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    driverCard

                    chatButton

                    tripSummaryCard
                }
                .padding(.bottom, 12)
            }

            Button(role: .destructive) {
                viewModel.showCancelConfirmation = true
            } label: {
                Text("Cancel Ride")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .confirmationDialog(
            "Cancel this ride?",
            isPresented: $viewModel.showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Ride", role: .destructive) {
                Task { await viewModel.cancelRide() }
            }
            Button("Keep Ride", role: .cancel) {}
        }
        .onAppear {
            if let rideId = viewModel.activeRide?.id, let uid = sessionManager.currentUser?.id {
                chatBadge.start(rideId: rideId, currentUserId: uid)
            }
        }
    }

    private var driverCard: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: viewModel.assignedDriver?.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.assignedDriver?.name ?? "Driver")
                    .font(.body.weight(.semibold))

                if let rating = viewModel.assignedDriver?.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let vehicle = viewModel.assignedDriver?.vehicle {
                    Text("\(vehicle.color) \(vehicle.model) • \(vehicle.plateNumber)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var chatButton: some View {
        Button {
            if let rideId = viewModel.activeRide?.id {
                router.push(.chat(rideId: rideId))
            }
        } label: {
            HStack {
                Image(systemName: "message.fill")
                Text("Chat with driver")
                Spacer()
                if chatBadge.unreadCount > 0 {
                    Text("\(chatBadge.unreadCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var tripSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(viewModel.pickupAddress, systemImage: "circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Label(viewModel.dropoffAddress, systemImage: "mappin")
                .foregroundStyle(.red)
                .font(.subheadline)
            HStack {
                Text(viewModel.selectedVehicleType.displayName)
                Text("•")
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", viewModel.fareEstimate.total)) estimated")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    DriverAssignedRideView(
        viewModel: BookRideViewModel(
            pickupAddress: "123 Main St",
            pickupCoordinate: nil,
            dropoffAddress: "456 Market St",
            dropoffCoordinate: nil,
            distanceKm: 5.2,
            durationMin: 14
        )
    )
    .environmentObject(Router())
    .environmentObject(SessionManager())
}
