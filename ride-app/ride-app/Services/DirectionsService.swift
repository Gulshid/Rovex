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
//  FIXED — Apple's MKDirections routing engine doesn't have coverage in
//  every country (Pakistan among them — Apple confirms turn-by-turn
//  directions aren't available there yet). In an unsupported region,
//  `directions.calculate()` throws MKError.directionsNotAvailable, which
//  used to bubble straight up and dead-end the "Book a Ride" flow with a
//  "Couldn't calculate route" alert. Now: if MKDirections fails for *any*
//  reason, we fall back to a straight-line (haversine) distance and a
//  rough time estimate instead, so the rest of the app — fare estimate,
//  ETA, live tracking — keeps working everywhere. `RoutePreview.isEstimated`
//  tells the UI when it's showing a fallback estimate instead of a real
//  route, so it can skip drawing a polyline / show a small note.
//

import Foundation
import MapKit
import CoreLocation

struct RoutePreview {
    /// nil when MKDirections had no coverage and we fell back to a
    /// straight-line estimate — there's no real road polyline to draw.
    let route: MKRoute?
    let distanceKm: Double
    let durationMin: Double
    /// true when `distanceKm`/`durationMin` are a straight-line fallback
    /// estimate rather than an actual MapKit-calculated route.
    let isEstimated: Bool
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

    /// Rough average driving speed used for the straight-line fallback
    /// estimate, in km/h. Deliberately conservative (city traffic, not
    /// highway) since it's standing in for a *lack* of real routing data.
    private let fallbackAverageSpeedKmh: Double = 30.0

    private init() {}

    /// Driving route + distance/duration between two coordinates. Tries a
    /// real MKDirections route first; if that's unavailable for this
    /// region (or fails for any other reason), returns a straight-line
    /// estimate instead of throwing — see the file header for why.
    func route(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> RoutePreview {

        if let preview = try? await calculateRoute(from: origin, to: destination) {
            return preview
        }
        return straightLineEstimate(from: origin, to: destination)
    }

    private func calculateRoute(
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
            // Empty result without a thrown error — treat the same as
            // "no coverage" and let the caller fall back.
            throw DirectionsError.noRouteFound
        }

        return RoutePreview(
            route: route,
            distanceKm: route.distance / 1000.0,
            durationMin: route.expectedTravelTime / 60.0,
            isEstimated: false
        )
    }

    private func straightLineEstimate(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) -> RoutePreview {
        let distanceKm = GeoUtils.distanceKm(origin, destination)
        let durationMin = (distanceKm / fallbackAverageSpeedKmh) * 60.0

        return RoutePreview(
            route: nil,
            distanceKm: distanceKm,
            durationMin: durationMin,
            isEstimated: true
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
