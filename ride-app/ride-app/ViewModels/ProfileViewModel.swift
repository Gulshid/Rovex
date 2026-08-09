//
//  ProfileViewModel.swift
//  RideBookingApp
//
//  UPDATED in Phase 5.
//  Phase 3 already has this ViewModel with name/phone/email bindings —
//  this adds the actual image-upload wiring that Phase 3 left as a TODO
//  ("upload handled in Phase 5"). Merge into your existing
//  ProfileViewModel.swift rather than overwriting if you already have
//  other properties/methods there.
//

import Foundation
import SwiftUI
import PhotosUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Existing from Phase 3 (kept for context)
    @Published var user: User?
    @Published var name: String = ""
    @Published var phone: String = ""

    // MARK: - New in Phase 5 - image upload state
    @Published var profilePhotoUploadState: CloudinaryUploadState = .idle
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var profileImagePreview: Image?

    private let userService = UserService.shared
    private let cloudinaryService = CloudinaryService.shared

    /// Call this when `selectedPhotoItem` changes (PhotosPicker's onChange).
    func handleSelectedPhoto(uid: String) {
        guard let item = selectedPhotoItem else { return }

        Task {
            do {
                guard
                    let data = try await item.loadTransferable(type: Data.self),
                    let uiImage = UIImage(data: data)
                else {
                    profilePhotoUploadState = .failure(message: "Couldn't load the selected photo.")
                    return
                }

                profileImagePreview = Image(uiImage: uiImage)
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

                try await userService.updateProfilePhotoURL(uid: uid, url: url)

                profilePhotoUploadState = .success(url: url)
                user?.photoURL = url

            } catch {
                profilePhotoUploadState = .failure(message: error.localizedDescription)
            }
        }
    }
}
