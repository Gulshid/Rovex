//
//  SOSService.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (SOS/Emergency)
//
//  Practice-app stand-in for a real emergency dispatch integration: no
//  such backend exists here, so "sending" an SOS means (a) writing a
//  timestamped record to a lightweight `sosAlerts` collection so it's at
//  least durably logged, and (b) building a shareable message the person
//  can actually send via SwiftUI's ShareLink (Messages/Mail/etc.) to a
//  real emergency contact, since that's the only way this environment can
//  genuinely notify anyone in the real world. See SOSButton.swift for how
//  the share sheet is presented.
//

import Foundation
import CoreLocation
import FirebaseFirestore

final class SOSService {

    static let shared = SOSService()
    private let db = Firestore.firestore()

    private init() {}

    /// Builds the human-readable message shared via ShareLink — includes
    /// a plain-text coordinate (a real integration would use a proper
    /// maps deep link, but that needs no API key here and works
    /// everywhere).
    func emergencyMessage(
        userName: String,
        rideId: String?,
        coordinate: CLLocationCoordinate2D?
    ) -> String {
        var lines = ["\(userName) has triggered an SOS alert during a Rovex ride."]
        if let rideId {
            lines.append("Ride ID: \(rideId)")
        }
        if let coordinate {
            lines.append("Current location: https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)")
        }
        lines.append("Sent \(Date().formatted(date: .abbreviated, time: .shortened))")
        return lines.joined(separator: "\n")
    }

    /// Best-effort log entry — failure here shouldn't block the share
    /// sheet from presenting, since the share sheet IS the actual alert.
    func logAlert(userId: String, rideId: String?, coordinate: CLLocationCoordinate2D?) async {
        var data: [String: Any] = [
            "userId": userId,
            "triggeredAt": FieldValue.serverTimestamp()
        ]
        if let rideId { data["rideId"] = rideId }
        if let coordinate {
            data["location"] = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        try? await db.collection("sosAlerts").addDocument(data: data)
    }
}
