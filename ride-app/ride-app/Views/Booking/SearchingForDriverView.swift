//
//  SearchingForDriverView.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Shown while ride.status == "requested". A simple pulsing radar
//  animation plus a Cancel Ride action with a confirmation dialog.
//

import SwiftUI

struct SearchingForDriverView: View {

    @ObservedObject var viewModel: BookRideViewModel
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(isPulsing ? 1.8 : 1)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.4),
                            value: isPulsing
                        )
                }

                Image(systemName: "car.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 90, height: 90)
                    .background(Circle().fill(.background))
            }
            .frame(height: 140)
            .onAppear { isPulsing = true }

            Text("Searching for a nearby driver…")
                .font(.title3.weight(.semibold))

            Text("This usually takes less than a minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

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
            Button("Keep Searching", role: .cancel) {}
        }
    }
}

#Preview {
    SearchingForDriverView(
        viewModel: BookRideViewModel(
            pickupAddress: "123 Main St",
            pickupCoordinate: nil,
            dropoffAddress: "456 Market St",
            dropoffCoordinate: nil,
            distanceKm: 5.2,
            durationMin: 14
        )
    )
}
