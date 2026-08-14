//
//  EditProfileView.swift
//  RideBookingApp
//
//  Phase 3 — Edit name/phone/photo; drivers also get a link into
//  VehicleDetailsView. Photo upload to Cloudinary lands in Phase 5 —
//  for now the picked image is only previewed locally.
//
//  UPDATED in Phase 14 — added links to FavoriteLocationsView (rider-
//  focused, but harmless to show for drivers too) and
//  EmergencyContactView.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Photo") {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                        photoPreview
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)

                Text("Photo uploads to Cloudinary in Phase 5 — for now it's stored locally as a preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Personal Info") {
                TextField("Full name", text: $viewModel.name)
                TextField("Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
            }

            if sessionManager.currentUser?.role == .driver {
                Section {
                    NavigationLink("Vehicle Details") {
                        VehicleDetailsView(viewModel: viewModel)
                    }
                }
            }

            Section("Ride Preferences") {
                NavigationLink("Favorite Locations") {
                    FavoriteLocationsView()
                }
                NavigationLink("Emergency Contact") {
                    EmergencyContactView()
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        guard let uid = sessionManager.currentUser?.id,
                              let role = sessionManager.currentUser?.role else { return }
                        if await viewModel.saveProfile(uid: uid, role: role) {
                            await sessionManager.refreshCurrentUser()
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .onAppear {
            if let user = sessionManager.currentUser {
                viewModel.load(from: user)
            }
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { await viewModel.loadSelectedPhoto() }
        }
    }

    private var photoPreview: some View {
        Group {
            if let data = viewModel.selectedPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = viewModel.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "camera.fill")
                }
            } else {
                Image(systemName: "camera.fill")
                    .font(.title)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { EditProfileView() }
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
