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
}
