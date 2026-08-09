//
//  VehicleDetailsView.swift
//  RideBookingApp
//
//  Phase 3 — Driver-only vehicle form (car model, plate, color, seats,
//  license photo). Values live on the shared ProfileViewModel and are
//  persisted together with the rest of the profile when the parent
//  EditProfileView is saved.
//

import SwiftUI
import PhotosUI

struct VehicleDetailsView: View {

    @ObservedObject var viewModel: ProfileViewModel

    @State private var licensePhotoItem: PhotosPickerItem?
    @State private var licensePhotoData: Data?

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
                        if let data = licensePhotoData, let uiImage = UIImage(data: data) {
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
                Text("Photo uploads to Cloudinary in Phase 5 — for now it's stored locally as a preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Vehicle Details")
        .onChange(of: licensePhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    licensePhotoData = data
                }
            }
        }
    }
}

#Preview {
    NavigationStack { VehicleDetailsView(viewModel: ProfileViewModel()) }
}
