//
//  ChatViewModel.swift
//  RideBookingApp
//
//  Phase 13 — Chat / In-App Communication
//
//  Drives ChatView: live message stream + sending. Also marks messages
//  "seen" (writes the newest message id to UserDefaults) every time a
//  fresh batch arrives, which is how ChatBadgeViewModel's unread count on
//  the previous screen knows to clear once the user actually opens chat.
//

import Foundation
import FirebaseAuth

@MainActor
final class ChatViewModel: ObservableObject {

    let rideId: String
    @Published private(set) var messages: [Message] = []
    @Published var draft: String = ""
    @Published var errorMessage: String?
    @Published private(set) var isSending = false

    static let quickReplies = ["On my way", "I've arrived", "Running a bit late"]

    private var observeTask: Task<Void, Never>?
    private let chatService = ChatService.shared

    var currentUserId: String? { Auth.auth().currentUser?.uid }

    init(rideId: String) {
        self.rideId = rideId
    }

    deinit {
        observeTask?.cancel()
    }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await messages in chatService.observeMessages(rideId: rideId) {
                    guard !Task.isCancelled else { return }
                    self.messages = messages
                    if let lastId = messages.last?.id {
                        UserDefaults.standard.set(lastId, forKey: ChatService.lastSeenDefaultsKey(rideId: self.rideId))
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Sends either the typed draft (`text == nil`) or a quick-reply
    /// string passed explicitly from a tapped chip.
    func send(_ text: String? = nil) async {
        guard let uid = currentUserId else { return }
        let messageText = text ?? draft
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await chatService.sendMessage(rideId: rideId, senderId: uid, text: messageText)
            if text == nil { draft = "" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Unread badge helper

/// Lightweight, ride-scoped unread counter for the small badge shown on
/// the "Chat" button in DriverAssignedRideView/ActiveDriverRideView —
/// deliberately separate from ChatViewModel so the badge can run without
/// the full chat screen being on-screen. Compares the live message stream
/// against whatever message id was last marked "seen" in UserDefaults
/// (see ChatViewModel.start()), which is good enough for a ride that only
/// lives a few minutes.
@MainActor
final class ChatBadgeViewModel: ObservableObject {

    @Published private(set) var unreadCount: Int = 0

    private var observeTask: Task<Void, Never>?
    private let chatService = ChatService.shared

    deinit {
        observeTask?.cancel()
    }

    func start(rideId: String, currentUserId: String) {
        guard observeTask == nil else { return }
        let lastSeenId = UserDefaults.standard.string(forKey: ChatService.lastSeenDefaultsKey(rideId: rideId))

        observeTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await messages in chatService.observeMessages(rideId: rideId) {
                    guard !Task.isCancelled else { return }
                    if let lastSeenId, let index = messages.firstIndex(where: { $0.id == lastSeenId }) {
                        self.unreadCount = messages[(index + 1)...].filter { $0.senderId != currentUserId }.count
                    } else {
                        self.unreadCount = messages.filter { $0.senderId != currentUserId }.count
                    }
                }
            } catch {
                // Best-effort badge — a failure here shouldn't surface as
                // a hard error on top of the active ride screen.
            }
        }
    }
}
