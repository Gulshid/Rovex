//
//  EmergencyContactView.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (SOS/Emergency)
//
//  Optional contact name/phone SOSButton's share sheet doesn't strictly
//  need (the person can pick any recipient in the native share sheet),
//  but saving one here means EditProfileView can show who it's set to
//  and the person doesn't have to remember a number under pressure.
//

import SwiftUI

@MainActor
final class EmergencyContactViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var phone: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let userService = UserService.shared

    func load(from user: AppUser) {
        name = user.emergencyContactName ?? ""
        phone = user.emergencyContactPhone ?? ""
    }

    func save(uid: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else {
            errorMessage = "Enter both a name and a phone number."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await userService.updateEmergencyContact(uid: uid, name: trimmedName, phone: trimmedPhone)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

struct EmergencyContactView: View {

    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = EmergencyContactViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Emergency Contact") {
                TextField("Contact name", text: $viewModel.name)
                TextField("Contact phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
            }

            Text("Used to pre-address the SOS share sheet during a ride. You can still pick a different recipient each time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Emergency Contact")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        guard let uid = sessionManager.currentUser?.id else { return }
                        if await viewModel.save(uid: uid) {
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
    }
}

#Preview {
    NavigationStack { EmergencyContactView() }
        .environmentObject(SessionManager())
}
