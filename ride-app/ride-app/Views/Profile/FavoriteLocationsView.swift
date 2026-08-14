//
//  FavoriteLocationsView.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (Favorite Locations)
//
//  Lets a rider set/clear a Home and Work address, geocoded once here via
//  CLGeocoder so AddressSearchView's quick-select chips can use the saved
//  coordinate directly. Reachable from EditProfileView.
//

import SwiftUI
import CoreLocation

@MainActor
final class FavoriteLocationsViewModel: ObservableObject {

    @Published var homeAddress: String = ""
    @Published var workAddress: String = ""
    @Published var isSavingHome = false
    @Published var isSavingWork = false
    @Published var errorMessage: String?

    private let userService = UserService.shared
    private let geocoder = CLGeocoder()

    func load(from user: AppUser) {
        homeAddress = user.homeAddress ?? ""
        workAddress = user.workAddress ?? ""
    }

    func saveHome(uid: String) async {
        await save(uid: uid, kind: .home, address: homeAddress, isSaving: \.isSavingHome)
    }

    func saveWork(uid: String) async {
        await save(uid: uid, kind: .work, address: workAddress, isSaving: \.isSavingWork)
    }

    private func save(
        uid: String,
        kind: UserService.FavoriteLocationKind,
        address: String,
        isSaving: ReferenceWritableKeyPath<FavoriteLocationsViewModel, Bool>
    ) async {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self[keyPath: isSaving] = true
        defer { self[keyPath: isSaving] = false }

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            guard let coordinate = placemarks.first?.location?.coordinate else {
                errorMessage = "Couldn't find that address."
                return
            }
            try await userService.updateFavoriteLocation(uid: uid, kind: kind, address: trimmed, coordinate: coordinate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear(uid: String, kind: UserService.FavoriteLocationKind) async {
        do {
            try await userService.clearFavoriteLocation(uid: uid, kind: kind)
            switch kind {
            case .home: homeAddress = ""
            case .work: workAddress = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FavoriteLocationsView: View {

    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = FavoriteLocationsViewModel()

    var body: some View {
        Form {
            Section("Home") {
                TextField("Home address", text: $viewModel.homeAddress)
                HStack {
                    Button("Save") {
                        if let uid = sessionManager.currentUser?.id {
                            Task { await viewModel.saveHome(uid: uid) }
                        }
                    }
                    .disabled(viewModel.isSavingHome || viewModel.homeAddress.trimmingCharacters(in: .whitespaces).isEmpty)

                    if viewModel.isSavingHome {
                        ProgressView()
                    }

                    Spacer()

                    if sessionManager.currentUser?.homeAddress?.isEmpty == false {
                        Button("Clear", role: .destructive) {
                            if let uid = sessionManager.currentUser?.id {
                                Task {
                                    await viewModel.clear(uid: uid, kind: .home)
                                    await sessionManager.refreshCurrentUser()
                                }
                            }
                        }
                    }
                }
            }

            Section("Work") {
                TextField("Work address", text: $viewModel.workAddress)
                HStack {
                    Button("Save") {
                        if let uid = sessionManager.currentUser?.id {
                            Task { await viewModel.saveWork(uid: uid) }
                        }
                    }
                    .disabled(viewModel.isSavingWork || viewModel.workAddress.trimmingCharacters(in: .whitespaces).isEmpty)

                    if viewModel.isSavingWork {
                        ProgressView()
                    }

                    Spacer()

                    if sessionManager.currentUser?.workAddress?.isEmpty == false {
                        Button("Clear", role: .destructive) {
                            if let uid = sessionManager.currentUser?.id {
                                Task {
                                    await viewModel.clear(uid: uid, kind: .work)
                                    await sessionManager.refreshCurrentUser()
                                }
                            }
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Favorite Locations")
        .onAppear {
            if let user = sessionManager.currentUser {
                viewModel.load(from: user)
            }
        }
    }
}

#Preview {
    NavigationStack { FavoriteLocationsView() }
        .environmentObject(SessionManager())
}
