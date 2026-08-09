//
//  ProfileViewModel.swift
//  RideBookingApp
//
//  Phase 3 — Backs EditProfileView (name/phone/photo) and
//  VehicleDetailsView (driver vehicle fields + license photo). Both
//  views share a single instance of this ViewModel, which is why
//  vehicle fields live here rather than in a separate ViewModel.
//
//  UPDATED in Phase 5 — saveProfile() now actually uploads any picked
//  profile photo / license photo to Cloudinary before writing the
//  resulting URLs to Firestore, closing the "upload handled in Phase 5"
//  TODO left by Phase 3.
//

import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Personal info (EditProfileView)
    @Published var name: String = ""
    @Published var phone: String = ""
    @Published var photoURL: String?

    // MARK: - Profile photo picker/upload (EditProfileView)
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var selectedPhotoData: Data?
    @Published var profilePhotoUploadState: CloudinaryUploadState = .idle

    // MARK: - Vehicle fields, driver only (VehicleDetailsView)
    @Published var vehicleModel: String = ""
    @Published var plateNumber: String = ""
    @Published var vehicleColor: String = ""
    @Published var seats: Int = 4

    // MARK: - License photo picker/upload, driver only (VehicleDetailsView)
    @Published var licensePhotoData: Data?
    @Published var licenseUploadState: CloudinaryUploadState = .idle

    // MARK: - Save state (EditProfileView toolbar button)
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let userService = UserService.shared
    private let cloudinaryService = CloudinaryService.shared

    /// Populates the form from the currently logged-in user.
    func load(from user: AppUser) {
        name = user.name
        phone = user.phone ?? ""
        photoURL = user.photoURL

        if let vehicle = user.vehicle {
            vehicleModel = vehicle.model
            plateNumber = vehicle.plateNumber
            vehicleColor = vehicle.color
            seats = vehicle.seats
        }
    }

    /// Loads the raw bytes for the picked profile photo so it can be
    /// previewed locally before Save is tapped.
    func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            selectedPhotoData = data
        }
    }

    /// Uploads any picked images to Cloudinary, then writes name/phone
    /// (and, for drivers, vehicle fields + photo URLs) to Firestore in
    /// one update. Returns true on success.
    func saveProfile(uid: String, role: UserRole) async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        do {
            var fields: [String: Any] = [
                "name": name.trimmingCharacters(in: .whitespaces),
                "phone": phone.trimmingCharacters(in: .whitespaces)
            ]

            // Profile photo, if a new one was picked
            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                profilePhotoUploadState = .uploading(progress: 0)
                let url = try await cloudinaryService.uploadImage(
                    uiImage,
                    folder: "profile_photos",
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.profilePhotoUploadState = .uploading(progress: progress)
                        }
                    }
                )
                fields["photoURL"] = url
                photoURL = url
                profilePhotoUploadState = .success(url: url)
            }

            // Driver-only vehicle fields
            if role == .driver {
                fields["vehicle.model"] = vehicleModel.trimmingCharacters(in: .whitespaces)
                fields["vehicle.plateNumber"] = plateNumber.trimmingCharacters(in: .whitespaces)
                fields["vehicle.color"] = vehicleColor.trimmingCharacters(in: .whitespaces)
                fields["vehicle.seats"] = seats

                if let data = licensePhotoData, let uiImage = UIImage(data: data) {
                    licenseUploadState = .uploading(progress: 0)
                    let url = try await cloudinaryService.uploadImage(
                        uiImage,
                        folder: "licenses",
                        onProgress: { [weak self] progress in
                            Task { @MainActor in
                                self?.licenseUploadState = .uploading(progress: progress)
                            }
                        }
                    )
                    fields["vehicle.licenseURL"] = url
                    licenseUploadState = .success(url: url)
                }
            }

            try await userService.updateProfileFields(uid: uid, fields: fields)
            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
