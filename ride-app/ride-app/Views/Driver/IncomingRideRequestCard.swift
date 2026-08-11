//
//  IncomingRideRequestCard.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//
//  The card DriverHomeView surfaces whenever DriverHomeViewModel finds a
//  nearby "requested" ride. Shows pickup/drop-off, estimated fare, and a
//  countdown ring that auto-rejects the request when it hits zero
//  (handled in the view model — this view is presentation-only).
//

import SwiftUI

struct IncomingRideRequestCard: View {

    let ride: Ride
    let countdownRemaining: Int
    let totalSeconds: Int
    let onAccept: () -> Void
    let onReject: () -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(countdownRemaining) / Double(totalSeconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New ride request")
                    .font(.headline)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(countdownRemaining)")
                        .font(.caption.monospacedDigit().bold())
                }
                .frame(width: 34, height: 34)
                .animation(.linear(duration: 1), value: countdownRemaining)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(ride.pickupLocation.address, systemImage: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                Label(ride.dropoffLocation.address, systemImage: "mappin")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            HStack {
                Label(ride.vehicleType.displayName, systemImage: ride.vehicleType.iconName)
                Spacer()
                if let fare = ride.estimatedFare {
                    Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", fare)) estimated")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onReject()
                } label: {
                    Text("Reject")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8, y: -2)
        .padding()
    }
}

#Preview {
    IncomingRideRequestCard(
        ride: Ride(
            riderId: "rider1",
            driverId: nil,
            pickupLocation: RideLocation(address: "123 Main St", geoPoint: .init(latitude: 0, longitude: 0)),
            dropoffLocation: RideLocation(address: "456 Market St", geoPoint: .init(latitude: 0, longitude: 0)),
            status: .requested,
            vehicleType: .comfort,
            estimatedFare: 12.40
        ),
        countdownRemaining: 9,
        totalSeconds: 15,
        onAccept: {},
        onReject: {}
    )
}
