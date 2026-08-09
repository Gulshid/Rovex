//
//  ProfileViewModel.swift
//  RideBookingApp
//
//  Phase 3 — Form state for editing a user's profile and (for drivers)
//  vehicle details. Photo pickers store the picked image locally for
//  preview only — actual Cloudinary upload arrives in Phase 5, at which
//  point `saveProfile` will also push photoURL/licenseURL/vehiclePhotoURL.
//

import SwiftUI
import PhotosUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // Personal info
    @Published var name = ""
    @Published var phone = ""
    @Published var photoURL: String?

    // Driver-only vehicle fields
    @Published var vehicleModel = ""
    @Published var plateNumber = ""
    @Published var vehicleColor = ""
    @Published var seats = 4
    @Published var licenseURL: String?
    @Published var vehiclePhotoURL: String?

    // Photo picker (profile photo)
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedPhotoData: Data?

    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    func load(from user: AppUser) {
        name = user.name
        phone = user.phone ?? ""
        photoURL = user.photoURL
        if let vehicle = user.vehicle {
            vehicleModel = vehicle.model
            plateNumber = vehicle.plateNumber
            vehicleColor = vehicle.color
            seats = vehicle.seats
            licenseURL = vehicle.licenseURL
            vehiclePhotoURL = vehicle.vehiclePhotoURL
        }
    }

    var nameValidationError: String? {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Name can't be empty." : nil
    }

    func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
            selectedPhotoData = data
        }
    }

    /// Saves personal info (and vehicle info, for drivers) to Firestore.
    func saveProfile(uid: String, role: UserRole) async -> Bool {
        errorMessage = nil
        if let validationError = nameValidationError {
            errorMessage = validationError
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await UserService.shared.updateProfile(
                uid: uid,
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone.isEmpty ? nil : phone
            )

            if role == .driver {
                let vehicle = VehicleDetails(
                    model: vehicleModel,
                    plateNumber: plateNumber,
                    color: vehicleColor,
                    seats: seats,
                    licenseURL: licenseURL,
                    vehiclePhotoURL: vehiclePhotoURL
                )
                try await UserService.shared.updateVehicle(uid: uid, vehicle: vehicle)
            }

            didSave = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
