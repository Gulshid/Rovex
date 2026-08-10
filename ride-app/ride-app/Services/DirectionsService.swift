//
//  DirectionsService.swift
//  RideBookingApp
//
//  Phase 6 — Maps, Location & Address Search
//
//  Wraps MKDirections (route + ETA) and CLGeocoder (address <-> coordinate).
//  Kept separate from AddressSearchViewModel so it can also be reused by
//  Phase 9 (recalculating ETA as the driver moves) without dragging in
//  MKLocalSearchCompleter/delegate plumbing.
//

import Foundation
import MapKit
import CoreLocation

struct RoutePreview {
    let route: MKRoute
    let distanceKm: Double
    let durationMin: Double
}

enum DirectionsError: LocalizedError {
    case noRouteFound
    case geocodingFailed

    var errorDescription: String? {
        switch self {
        case .noRouteFound: return "Couldn't find a route between these locations."
        case .geocodingFailed: return "Couldn't resolve that address to a location."
        }
    }
}

final class DirectionsService {

    static let shared = DirectionsService()
    private let geocoder = CLGeocoder()

    private init() {}

    /// Driving route + distance/duration between two coordinates.
    func route(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RoutePreview {

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw DirectionsError.noRouteFound
        }

        return RoutePreview(
            route: route,
            distanceKm: route.distance / 1000.0,
            durationMin: route.expectedTravelTime / 60.0
        )
    }

    /// Reverse-geocode a coordinate into a human-readable address
    /// (used for the "confirm pickup location" draggable-pin flow).
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw DirectionsError.geocodingFailed
        }
        return placemark.formattedAddress
    }
}

extension CLPlacemark {
    /// Best-effort single-line address string.
    var formattedAddress: String {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode
        ].compactMap { $0 }
        return components.isEmpty ? (name ?? "Unknown location") : components.joined(separator: ", ")
    }
}
