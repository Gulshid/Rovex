//
//  RideTrackingView.swift
//  RideBookingApp
//
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  Rider-side screen for opening live tracking on a ride by id alone
//  (Router.AppRoute.rideTracking) — for example re-opening an ongoing ride
//  from Ride History (Phase 12) or after relaunching the app mid-ride. The
//  ride just booked in this session already gets live tracking inline via
//  BookRideViewModel + DriverAssignedRideView; this view covers the
//  "reopen by id" case.
//

import SwiftUI

struct RideTrackingView: View {

    @StateObject private var viewModel: RideTrackingViewModel

    init(rideId: String) {
        _viewModel = StateObject(wrappedValue: RideTrackingViewModel(rideId: rideId))
    }

    var body: some View {
        VStack(spacing: 0) {
            LiveRideMapView(
                pickupCoordinate: viewModel.ride?.pickupLocation.geoPoint.clCoordinate,
                dropoffCoordinate: viewModel.ride?.dropoffLocation.geoPoint.clCoordinate,
                driverCoordinate: viewModel.driverLocation
            )
            .frame(maxHeight: .infinity)

            infoCard
        }
        .navigationTitle("Track Ride")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ride = viewModel.ride {
                Label(ride.pickupLocation.address, systemImage: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                Label(ride.dropoffLocation.address, systemImage: "mappin")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            HStack {
                if let driver = viewModel.driver {
                    Text(driver.name)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                if let eta = viewModel.etaMinutes {
                    Text("ETA \(Int(eta.rounded())) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    NavigationStack {
        RideTrackingView(rideId: "preview-ride-id")
    }
}
