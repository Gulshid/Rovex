//
//  Constants.swift
//  RideBookingApp
//
//  Phase 1 — Central place for environment config, API keys & endpoints.
//  Never commit real secrets to a public repo. For a practice/private repo
//  this is fine, but consider a `Secrets.xcconfig` (gitignored) if you later
//  make the repo public.
//

import Foundation

enum AppEnvironment {
    #if DEBUG
    static let current = "Debug"
    #else
    static let current = "Release"
    #endif
}

enum Constants {

    enum Cloudinary {
        // Fill these in during Phase 0 / Phase 5 from your Cloudinary console
        static let cloudName = "df0saqabg"
        static let uploadPreset = "rovex_unsigned"
        static var uploadURL: String {
            "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
        }
    }

    enum Firestore {
        static let usersCollection = "users"
        static let ridesCollection = "rides"
        static let driversCollection = "drivers"
        static let ratingsSubcollection = "ratings"
        static let promoCodesCollection = "promoCodes"
    }

    enum App {
        static let minimumIOSVersion = "16.0"
        static let bundleIdentifier = "com.yourname.RideBookingApp"
    }

    // MARK: - Phase 7 / 10 — Fare engine
    //
    // Simple base + per-km + per-minute formula, multiplied per vehicle
    // type. Values are placeholders for a practice project — tune freely.
    enum Fare {
        struct Rates {
            let baseFare: Double
            let perKm: Double
            let perMinute: Double
            let minimumFare: Double
        }

        static func rates(for vehicleType: VehicleType) -> Rates {
            switch vehicleType {
            case .economy:
                return Rates(baseFare: 2.00, perKm: 0.80, perMinute: 0.15, minimumFare: 4.00)
            case .comfort:
                return Rates(baseFare: 3.00, perKm: 1.10, perMinute: 0.20, minimumFare: 6.00)
            case .xl:
                return Rates(baseFare: 4.00, perKm: 1.40, perMinute: 0.25, minimumFare: 8.00)
            }
        }

        static let currencySymbol = "$"
    }

    // MARK: - Phase 8 — Driver matching
    //
    // Firestore has no native radius query, so nearby-driver matching is a
    // "requested" rides listener filtered client-side with GeoUtils. Tuned
    // for a practice app running on the free Spark plan — raise the radius
    // or timeout freely.
    enum Matching {
        static let searchRadiusKm: Double = 8.0
        static let requestTimeoutSeconds: Int = 15
    }

    // MARK: - Phase 9 — Live location tracking
    //
    // How often the driver's device writes its coordinate back to
    // Firestore while online/on a ride. Every write costs a Firestore
    // write op, so keep this modest for the free tier.
    enum Tracking {
        static let driverLocationUpdateInterval: TimeInterval = 4.0
    }
}
