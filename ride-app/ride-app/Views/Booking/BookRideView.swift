//
//  BookRideView.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Entry point after MapBookingView (Phase 6). Shows pickup/drop-off
//  summary, a vehicle type selector with live fare estimate, and a
//  "Confirm Ride" button. Once booked, swaps to a live status view driven
//  by BookRideViewModel.phase (searching → driver assigned → ongoing).
//
//  UPDATED in Phase 12 — `.completed` now shows the real RideReceiptView
//  (it existed since Phase 10 but was never actually wired in here — this
//  was showing a generic "Ride completed" status screen instead) with a
//  "Rate Your Driver" action that pushes `.rateRide`.
//

import SwiftUI
import CoreLocation

struct BookRideView: View {

    @StateObject private var viewModel: BookRideViewModel
    @EnvironmentObject private var router: Router

    init(
        pickupAddress: String,
        pickupCoordinate: CLLocationCoordinate2D?,
        dropoffAddress: String,
        dropoffCoordinate: CLLocationCoordinate2D?,
        distanceKm: Double?,
        durationMin: Double?
    ) {
        _viewModel = StateObject(wrappedValue: BookRideViewModel(
            pickupAddress: pickupAddress,
            pickupCoordinate: pickupCoordinate,
            dropoffAddress: dropoffAddress,
            dropoffCoordinate: dropoffCoordinate,
            distanceKm: distanceKm,
            durationMin: durationMin
        ))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .booking:
                vehicleSelectionScreen
            case .searching:
                SearchingForDriverView(viewModel: viewModel)
            case .driverAssigned, .ongoing:
                DriverAssignedRideView(viewModel: viewModel)
            case .completed:
                RideReceiptView(
                    ride: viewModel.activeRide,
                    walletChargeError: viewModel.walletChargeError,
                    onRate: {
                        if let rideId = viewModel.activeRide?.id,
                           let driverId = viewModel.activeRide?.driverId {
                            router.push(.rateRide(rideId: rideId, ratedUserId: driverId, isDriver: false))
                        }
                    },
                    onDone: {
                        router.popToRoot()
                    }
                )
            case .cancelled:
                statusScreen(
                    icon: "xmark.circle.fill",
                    tint: .red,
                    title: "Ride cancelled",
                    message: "You can book another ride any time."
                )
            case .failed(let message):
                statusScreen(
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: "Something went wrong",
                    message: message
                )
            }
        }
        .navigationTitle("Choose a ride")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase != .idle)
    }

    // MARK: - Idle / vehicle selection

    private var vehicleSelectionScreen: some View {
        VStack(spacing: 0) {
            tripSummary
                .padding()

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        VehicleOptionRow(
                            type: type,
                            isSelected: viewModel.selectedVehicleType == type,
                            estimate: FareEstimator.estimate(
                                distanceKm: viewModel.distanceKm,
                                durationMin: viewModel.durationMin,
                                vehicleType: type
                            )
                        )
                        .onTapGesture {
                            viewModel.selectedVehicleType = type
                        }
                    }
                }
                .padding()
            }

            confirmBar
        }
    }

    private var tripSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(viewModel.pickupAddress, systemImage: "circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Label(viewModel.dropoffAddress, systemImage: "mappin")
                .foregroundStyle(.red)
                .font(.subheadline)
            HStack {
                Text(String(format: "%.1f km", viewModel.distanceKm))
                Text("•")
                Text(String(format: "%.0f min", viewModel.durationMin))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmBar: some View {
        VStack(spacing: 8) {
            if case .failed(let message) = viewModel.phase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.confirmRide() }
            } label: {
                HStack {
                    if viewModel.phase == .booking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Confirm \(viewModel.selectedVehicleType.displayName) • \(Constants.Fare.currencySymbol)\(String(format: "%.2f", viewModel.fareEstimate.total))")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConfirmRide || viewModel.phase == .booking)
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Terminal states

    private func statusScreen(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Back to Home") {
                router.popToRoot()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Vehicle option row

private struct VehicleOptionRow: View {
    let type: VehicleType
    let isSelected: Bool
    let estimate: FareEstimator.Estimate

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: type.iconName)
                .font(.title2)
                .frame(width: 40)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.body.weight(.semibold))
                Text(type.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", estimate.total))")
                .font(.body.weight(.semibold))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

extension VehicleType {
    var displayName: String {
        switch self {
        case .economy: return "Economy"
        case .comfort: return "Comfort"
        case .xl: return "XL"
        }
    }

    var subtitle: String {
        switch self {
        case .economy: return "Affordable, everyday rides"
        case .comfort: return "Newer cars, extra legroom"
        case .xl: return "Bigger cars for groups"
        }
    }

    var iconName: String {
        switch self {
        case .economy: return "car.fill"
        case .comfort: return "car.side.fill"
        case .xl: return "bus.fill"
        }
    }
}

#Preview {
    NavigationStack {
        BookRideView(
            pickupAddress: "123 Main St",
            pickupCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            dropoffAddress: "456 Market St",
            dropoffCoordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            distanceKm: 5.2,
            durationMin: 14
        )
        .environmentObject(Router())
    }
}
