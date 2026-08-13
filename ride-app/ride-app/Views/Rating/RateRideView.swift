//
//  RateRideView.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Shown right after a ride completes — a simple star picker + optional
//  comment, matching the roadmap's "Rate Your Ride screen shown right
//  after a ride completes". Reached from BookRideView (rider rating the
//  driver) and ActiveDriverRideView (driver rating the rider), and again
//  later from RideDetailView for anyone revisiting a completed ride in
//  their history who hasn't rated yet.
//

import SwiftUI

struct RateRideView: View {

    @StateObject private var viewModel: RateRideViewModel
    @EnvironmentObject private var router: Router

    init(rideId: String, ratedUserId: String, isDriver: Bool) {
        _viewModel = StateObject(wrappedValue: RateRideViewModel(
            rideId: rideId,
            ratedUserId: ratedUserId,
            isDriver: isDriver
        ))
    }

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.didSubmit {
                confirmation
            } else {
                form
            }
        }
        .padding()
        .navigationTitle("Rate Your Ride")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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

    private var form: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How was your \(viewModel.isDriver ? "rider" : "driver")?")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            starPicker

            TextField("Add a comment (optional)", text: $viewModel.comment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Spacer()

            Button {
                Task { await viewModel.submit() }
            } label: {
                HStack {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text("Submit Rating")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isSubmitting)

            Button("Skip") {
                router.popToRoot()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var starPicker: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= viewModel.value ? "star.fill" : "star")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                    .onTapGesture {
                        viewModel.value = star
                    }
            }
        }
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Thanks for your feedback!")
                .font(.title3.weight(.semibold))
            Button("Done") {
                router.popToRoot()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        RateRideView(rideId: "preview-ride-id", ratedUserId: "preview-user-id", isDriver: false)
            .environmentObject(Router())
    }
}
