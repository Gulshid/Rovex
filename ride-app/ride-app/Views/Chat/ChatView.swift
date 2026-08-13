//
//  ChatView.swift
//  RideBookingApp
//
//  Phase 13 — Chat / In-App Communication
//
//  Simple real-time text chat tied to one active ride, reachable from
//  both DriverAssignedRideView (rider side) and ActiveDriverRideView
//  (driver side) once a driver is assigned. Includes the quick-reply
//  chips the roadmap calls out ("On my way", "I've arrived").
//

import SwiftUI

struct ChatView: View {

    @StateObject private var viewModel: ChatViewModel

    init(rideId: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(rideId: rideId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            quickReplies
            inputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func bubble(_ message: Message) -> some View {
        let isMine = message.senderId == viewModel.currentUserId
        return HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isMine ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(isMine ? .white : .primary)
            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private var quickReplies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatViewModel.quickReplies, id: \.self) { reply in
                    Button(reply) {
                        Task { await viewModel.send(reply) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $viewModel.draft)
                .textFieldStyle(.roundedBorder)

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    NavigationStack {
        ChatView(rideId: "preview-ride-id")
    }
}
