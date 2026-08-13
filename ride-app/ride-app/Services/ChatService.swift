//
//  ChatService.swift
//  RideBookingApp
//
//  Phase 13 — Chat / In-App Communication
//
//  Messages live in a `messages` subcollection under each ride document
//  (rides/{rideId}/messages/{messageId} — see Models/Message.swift).
//  Access is restricted to the ride's two participants directly in
//  firestore.rules, fulfilling the roadmap's Phase 13 note that this
//  restriction belongs "in Firestore rules — Phase 16" a little early,
//  since it's needed for basic correctness the moment chat exists at all.
//
//  sendMessage uses the same checked-continuation pattern as
//  RideService.requestRide rather than a bare completion handler, for the
//  same reason documented there: it guarantees the write is actually
//  committed before the caller does anything else (clears the draft,
//  etc.) instead of being fire-and-forget.
//

import Foundation
import FirebaseFirestore

final class ChatService {

    static let shared = ChatService()
    private let db = Firestore.firestore()

    private init() {}

    private func messagesCollection(rideId: String) -> CollectionReference {
        db.collection(Constants.Firestore.ridesCollection)
            .document(rideId)
            .collection("messages")
    }

    /// UserDefaults key used to remember the last message id a given
    /// device has actually opened Chat to see — shared between
    /// ChatViewModel (which updates it) and ChatBadgeViewModel (which
    /// reads it) without the two needing a shared object instance.
    static func lastSeenDefaultsKey(rideId: String) -> String {
        "chat.lastSeenMessageId.\(rideId)"
    }

    func sendMessage(rideId: String, senderId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = Message(senderId: senderId, text: trimmed)
        let ref = messagesCollection(rideId: rideId).document()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try ref.setData(from: message) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Live stream of every message on this ride, oldest first.
    func observeMessages(rideId: String) -> AsyncThrowingStream<[Message], Error> {
        AsyncThrowingStream { continuation in
            let listener = messagesCollection(rideId: rideId)
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    let messages = snapshot.documents.compactMap { try? $0.data(as: Message.self) }
                    continuation.yield(messages)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
