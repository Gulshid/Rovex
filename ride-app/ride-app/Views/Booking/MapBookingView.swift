//
//  MapBookingView.swift
//  RideBookingApp
//
//  Phase 6 — Maps, Location & Address Search
//
//  The visual core of the app: a live map with pickup/drop-off pins, a
//  route preview line, distance/ETA, and a "confirm pickup location"
//  draggable-pin interaction. "Continue" hands off to BookRideView
//  (Phase 7) to pick a vehicle type and actually request the ride.
//
//  FIXED — Apple's MKDirections has no routing coverage in some regions
//  (e.g. Pakistan), which used to surface as a dead-end "Couldn't
//  calculate route" alert. DirectionsService now falls back to a
//  straight-line estimate instead of throwing, so that alert only fires
//  for genuine failures now; a small inline note appears instead when
//  showing a straight-line estimate.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapBookingView: View {

    @StateObject private var viewModel = MapBookingViewModel()
    @EnvironmentObject private var router: Router
    @StateObject private var locationManager = LocationManager.shared

    @State private var activeSearchField: AddressField?

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer

            if viewModel.isAdjustingPickupPin {
                centerPinOverlay
                confirmPinBar
            } else {
                bookingCard
            }
        }
        .navigationTitle("Book a Ride")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            locationManager.requestPermissionIfNeeded()
            await viewModel.useCurrentLocationAsPickup()
        }
        .sheet(item: $activeSearchField) { field in
            AddressSearchView(field: field) { resolved in
                viewModel.apply(resolved, to: field)
            }
        }
        .alert(
            "Couldn't calculate route",
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

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {
            if let pickup = viewModel.pickupCoordinate {
                Marker("Pickup", systemImage: "circle.fill", coordinate: pickup)
                    .tint(.green)
            }
            if let dropoff = viewModel.dropoffCoordinate {
                Marker("Drop-off", systemImage: "mappin", coordinate: dropoff)
                    .tint(.red)
            }
            if let route = viewModel.route {
                MapPolyline(route.polyline)
                    .stroke(Color.accentColor, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            if viewModel.isAdjustingPickupPin {
                viewModel.pinDidMove(to: context.region.center)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var centerPinOverlay: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.red)
                .offset(y: -17) // tip of pin points at the exact center
            Circle()
                .fill(.black.opacity(0.25))
                .frame(width: 8, height: 8)
                .offset(y: -6)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - "Confirm pickup" bar (draggable pin flow)

    private var confirmPinBar: some View {
        VStack(spacing: 12) {
            Text("Drag the map to move the pin")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    viewModel.isAdjustingPickupPin = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task { await viewModel.confirmDraggedPin() }
                } label: {
                    if viewModel.isResolvingPin {
                        ProgressView()
                    } else {
                        Text("Confirm pickup location")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isResolvingPin)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    // MARK: - Booking card

    private var bookingCard: some View {
        VStack(spacing: 14) {
            addressRow(
                icon: "circle.fill",
                iconColor: .green,
                placeholder: "Pickup location",
                text: viewModel.pickupAddress,
                field: .pickup,
                trailing: {
                    Button {
                        viewModel.isAdjustingPickupPin = true
                    } label: {
                        Image(systemName: "hand.point.up.left")
                    }
                    .buttonStyle(.plain)
                }
            )

            Divider()

            addressRow(
                icon: "mappin",
                iconColor: .red,
                placeholder: "Where to?",
                text: viewModel.dropoffAddress,
                field: .dropoff,
                trailing: { EmptyView() }
            )

            if viewModel.isCalculatingRoute {
                ProgressView("Calculating route…")
                    .frame(maxWidth: .infinity)
            } else if let distance = viewModel.distanceKm, let duration = viewModel.durationMin {
                VStack(spacing: 4) {
                    HStack {
                        Label(String(format: "%.1f km", distance), systemImage: "arrow.left.and.right")
                        Spacer()
                        Label(String(format: "%.0f min", duration), systemImage: "clock")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                    if viewModel.isRouteEstimated {
                        Text("Estimated — live directions aren't available in this area")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                router.push(.toBookRide(
                    pickupAddress: viewModel.pickupAddress,
                    pickupCoordinate: viewModel.pickupCoordinate,
                    dropoffAddress: viewModel.dropoffAddress,
                    dropoffCoordinate: viewModel.dropoffCoordinate,
                    distanceKm: viewModel.distanceKm,
                    durationMin: viewModel.durationMin
                ))
            } label: {
                Text("Choose a ride")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConfirmRoute)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }

    @ViewBuilder
    private func addressRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: String,
        field: AddressField,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Button {
            activeSearchField = field
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                trailing()
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

extension AddressField: Identifiable {
    var id: Self { self }
}

#Preview {
    NavigationStack {
        MapBookingView()
            .environmentObject(Router())
    }
}
