//
//  MapBookingViewModel.swift
//  RideBookingApp
//
//  Phase 6 — Maps, Location & Address Search
//
//  Owns pickup/drop-off selection, the current map camera, and the route
//  preview (distance + ETA) shown on the booking screen. Phase 7 reads
//  `pickupAddress` / `pickupCoordinate` / `dropoffAddress` /
//  `dropoffCoordinate` / `distanceKm` / `durationMin` straight off this
//  view model when it creates the Ride document.
//

import Foundation
import MapKit
import CoreLocation
import Combine

enum AddressField {
    case pickup
    case dropoff
}

@MainActor
final class MapBookingViewModel: ObservableObject {

    // MARK: - Published state

    @Published var pickupAddress: String = ""
    @Published var pickupCoordinate: CLLocationCoordinate2D?

    @Published var dropoffAddress: String = ""
    @Published var dropoffCoordinate: CLLocationCoordinate2D?

    @Published var route: MKRoute?
    @Published var distanceKm: Double?
    @Published var durationMin: Double?

    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // sensible default; replaced once we have a real fix
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    /// Draggable "confirm pickup" pin — center of the map while the user
    /// fine-tunes their exact pickup spot.
    @Published var isAdjustingPickupPin = false
    @Published var draggablePinCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @Published var isResolvingPin = false

    @Published var isCalculatingRoute = false
    @Published var errorMessage: String?

    private let locationManager: LocationManager
    private let directionsService: DirectionsService

    var canConfirmRoute: Bool {
        pickupCoordinate != nil && dropoffCoordinate != nil
    }

    init(
        locationManager: LocationManager = .shared,
        directionsService: DirectionsService = .shared
    ) {
        self.locationManager = locationManager
        self.directionsService = directionsService
    }

    // MARK: - Setup

    /// Call from the map screen's onAppear. Centers the map on the rider's
    /// current location and defaults pickup to "current location".
    func useCurrentLocationAsPickup() async {
        locationManager.requestPermissionIfNeeded()

        guard let coordinate = locationManager.currentLocation else { return }

        pickupCoordinate = coordinate
        draggablePinCoordinate = coordinate
        cameraPosition = .region(
            MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        )

        do {
            pickupAddress = try await directionsService.reverseGeocode(coordinate)
        } catch {
            pickupAddress = "Current Location"
        }
    }

    // MARK: - Address selection (from AddressSearchView)

    func apply(_ resolved: ResolvedAddress, to field: AddressField) {
        switch field {
        case .pickup:
            pickupAddress = resolved.address
            pickupCoordinate = resolved.coordinate
            draggablePinCoordinate = resolved.coordinate
        case .dropoff:
            dropoffAddress = resolved.address
            dropoffCoordinate = resolved.coordinate
        }
        recenter(on: resolved.coordinate)
        Task { await calculateRouteIfPossible() }
    }

    private func recenter(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        )
    }

    // MARK: - Draggable "confirm pickup" pin

    /// Called while the user drags the center pin around the map.
    func pinDidMove(to coordinate: CLLocationCoordinate2D) {
        draggablePinCoordinate = coordinate
    }

    /// Called on "Confirm pickup location" — reverse-geocodes the pin's
    /// final resting position and locks it in as the pickup point.
    func confirmDraggedPin() async {
        isResolvingPin = true
        defer { isResolvingPin = false }

        pickupCoordinate = draggablePinCoordinate
        do {
            pickupAddress = try await directionsService.reverseGeocode(draggablePinCoordinate)
        } catch {
            pickupAddress = "Dropped Pin"
        }
        isAdjustingPickupPin = false
        await calculateRouteIfPossible()
    }

    // MARK: - Route calculation

    func calculateRouteIfPossible() async {
        guard let pickup = pickupCoordinate, let dropoff = dropoffCoordinate else { return }

        isCalculatingRoute = true
        errorMessage = nil
        defer { isCalculatingRoute = false }

        do {
            let preview = try await directionsService.route(from: pickup, to: dropoff)
            route = preview.route
            distanceKm = preview.distanceKm
            durationMin = preview.durationMin

            cameraPosition = .rect(preview.route.polyline.boundingMapRect.insetBy(dx: -2000, dy: -2000))
        } catch {
            errorMessage = error.localizedDescription
            route = nil
            distanceKm = nil
            durationMin = nil
        }
    }

    func reset() {
        pickupAddress = ""
        pickupCoordinate = nil
        dropoffAddress = ""
        dropoffCoordinate = nil
        route = nil
        distanceKm = nil
        durationMin = nil
    }
}
