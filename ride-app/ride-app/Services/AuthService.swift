//
//  AuthService.swift
//  RideBookingApp
//
//  Phase 2 — Wraps FirebaseAuth calls with async/await and creates the
//  matching Firestore `users` document on sign-up.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "That email address doesn't look right."
        case .weakPassword: return "Password should be at least 6 characters."
        case .userNotFound: return "No account found with that email."
        case .wrongPassword: return "Incorrect password. Please try again."
        case .emailAlreadyInUse: return "An account with this email already exists."
        case .unknown(let message): return message
        }
    }

    init(_ error: Error) {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            self = .unknown(error.localizedDescription)
            return
        }
        switch code {
        case .invalidEmail: self = .invalidEmail
        case .weakPassword: self = .weakPassword
        case .userNotFound: self = .userNotFound
        case .wrongPassword: self = .wrongPassword
        case .emailAlreadyInUse: self = .emailAlreadyInUse
        default: self = .unknown(nsError.localizedDescription)
        }
    }
}

@MainActor
final class AuthService {

    static let shared = AuthService()
    private init() {}

    private let db = Firestore.firestore()

    /// Creates a Firebase Auth account AND the matching Firestore user document.
    func signUp(name: String, email: String, password: String, role: UserRole) async throws -> AppUser {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try? await changeRequest.commitChanges()

            let newUser = AppUser(
                id: uid,
                name: name,
                email: email,
                role: role,
                phone: nil,
                photoURL: nil,
                isAvailable: role == .driver ? false : nil,
                vehicle: role == .driver
                    ? VehicleDetails(model: "", plateNumber: "", color: "", seats: 4, licenseURL: nil, vehiclePhotoURL: nil)
                    : nil,
                createdAt: Date()
            )

            try db.collection(Constants.Firestore.usersCollection)
                .document(uid)
                .setData(from: newUser)

            return newUser
        } catch {
            throw AuthError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return try await UserService.shared.fetchUser(uid: result.user.uid)
        } catch {
            throw AuthError(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError(error)
        }
    }

    var currentUID: String? {
        Auth.auth().currentUser?.uid
    }
}
