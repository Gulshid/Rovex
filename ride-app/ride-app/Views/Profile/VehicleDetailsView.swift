//
//  VehicleDetailsView.swift
//  RideBookingApp
//
//  Phase 3 — Driver-only vehicle form (car model, plate, color, seats,
//  license photo). Values live on the shared ProfileViewModel and are
//  persisted together with the rest of the profile when the parent
//  EditProfileView is saved.
//
//  UPDATED in Phase 5 — the license photo picker used to store its
//  picked image in local @State, so it was never actually included in
//  the save. It now writes into viewModel.licensePhotoData, which
//  ProfileViewModel.saveProfile() uploads to Cloudinary and persists.
//

import SwiftUI
import PhotosUI

struct VehicleDetailsView: View {

    @ObservedObject var viewModel: ProfileViewModel

    @State private var licensePhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Car model (e.g. Toyota Corolla)", text: $viewModel.vehicleModel)
                TextField("Plate number", text: $viewModel.plateNumber)
                TextField("Color", text: $viewModel.vehicleColor)
                Stepper("Seats: \(viewModel.seats)", value: $viewModel.seats, in: 1...8)
            }

            Section("License Photo") {
                PhotosPicker(selection: $licensePhotoItem, matching: .images) {
                    HStack {
                        if let data = viewModel.licensePhotoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "doc.text.image")
                                .font(.title2)
                                .frame(width: 60, height: 60)
                        }
                        Text("Upload license photo")
                    }
                }

                if case .uploading(let progress) = viewModel.licenseUploadState {
                    ProgressView(value: progress)
                }
            }
        }
        .navigationTitle("Vehicle Details")
        .onChange(of: licensePhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    viewModel.licensePhotoData = data
                }
            }
        }
    }
}

#Preview {
    NavigationStack { VehicleDetailsView(viewModel: ProfileViewModel()) }
}
