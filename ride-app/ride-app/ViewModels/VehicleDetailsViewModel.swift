//
//  VehicleDetailsViewModel.swift
//  RideBookingApp
//
//  UPDATED in Phase 5.
//  Phase 3 built the Driver Vehicle Details form (car model, plate,
//  color, seats, license photo picker). This adds the Cloudinary
//  upload wiring for the vehicle photo and license photo, mirroring
//  ProfileViewModel's pattern. Merge into your existing
//  VehicleDetailsViewModel.swift if you already have one.
//

import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class VehicleDetailsViewModel: ObservableObject {

    // MARK: - Existing from Phase 3 (kept for context)
    @Published var carModel: String = ""
    @Published var plateNumber: String = ""
    @Published var color: String = ""
    @Published var seats: Int = 4

    // MARK: - New in Phase 5 - vehicle photo upload
    @Published var vehiclePhotoItem: PhotosPickerItem?
    @Published var vehiclePhotoUploadState: CloudinaryUploadState = .idle

    // MARK: - New in Phase 5 - license photo upload
    @Published var licensePhotoItem: PhotosPickerItem?
    @Published var licensePhotoUploadState: CloudinaryUploadState = .idle

    private let userService = UserService.shared
    private let cloudinaryService = CloudinaryService.shared

    func handleVehiclePhotoSelection(uid: String) {
        guard let item = vehiclePhotoItem else { return }
        Task {
            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data)
                else {
                    vehiclePhotoUploadState = .failure(message: "Couldn't load the selected photo.")
                    return
                }

                vehiclePhotoUploadState = .uploading(progress: 0)

                let url = try await cloudinaryService.uploadImage(
                    uiImage,
                    folder: "vehicle_photos",
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.vehiclePhotoUploadState = .uploading(progress: progress)
                        }
                    }
                )

                try await userService.updateVehiclePhotoURL(uid: uid, url: url)
                vehiclePhotoUploadState = .success(url: url)

            } catch {
                vehiclePhotoUploadState = .failure(message: error.localizedDescription)
            }
        }
    }

    func handleLicensePhotoSelection(uid: String) {
        guard let item = licensePhotoItem else { return }
        Task {
            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data)
                else {
                    licensePhotoUploadState = .failure(message: "Couldn't load the selected photo.")
                    return
                }

                licensePhotoUploadState = .uploading(progress: 0)

                let url = try await cloudinaryService.uploadImage(
                    uiImage,
                    folder: "licenses",
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.licensePhotoUploadState = .uploading(progress: progress)
                        }
                    }
                )

                try await userService.updateDriverLicenseURL(uid: uid, url: url)
                licensePhotoUploadState = .success(url: url)

            } catch {
                licensePhotoUploadState = .failure(message: error.localizedDescription)
            }
        }
    }
}
