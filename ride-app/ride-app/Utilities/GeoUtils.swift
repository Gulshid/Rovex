//
//  GeoUtils.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//
//  Firestore has no native "find documents within N km" query, so nearby
//  driver-matching (Phase 8) and live ETA recalculation (Phase 9) both need
//  a plain haversine distance helper to filter/sort client-side. Small and
//  dependency-free on purpose — this is the "simple radius filter using
//  GeoPoint math for practice" called out in the Phase 8 roadmap notes.
//

import Foundation
import CoreLocation
import FirebaseFirestore

enum GeoUtils {

    /// Great-circle (haversine) distance in kilometers between two coordinates.
    static func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6371.0

        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))

        return earthRadiusKm * c
    }

    static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        distanceKm(a.clCoordinate, b.clCoordinate)
    }
}

extension GeoPoint {
    /// Convenience bridge so Firestore's GeoPoint can be dropped straight
    /// into MapKit/CoreLocation APIs (Marker, MKDirections, GeoUtils, etc.)
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
