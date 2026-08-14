//
//  SOSButton.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (SOS/Emergency)
//
//  Reusable emergency button embedded on both active-ride screens
//  (DriverAssignedRideView for riders, ActiveDriverRideView for
//  drivers). Requires a confirmation tap (accidental taps during an
//  active ride would be worse than a slightly slower real emergency),
//  then logs the alert and presents a native share sheet pre-filled with
//  ride + location details — see SOSService's header for why sharing is
//  the actual notification mechanism in a practice app with no real
//  emergency-dispatch backend.
//

import SwiftUI
import CoreLocation

struct SOSButton: View {

    let userName: String
    let userId: String
    let rideId: String?
    let coordinate: CLLocationCoordinate2D?

    @State private var showConfirmation = false
    @State private var showShareSheet = false
    @State private var messageToShare = ""

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            Image(systemName: "sos")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.red, in: Circle())
        }
        .accessibilityLabel("Emergency SOS")
        .confirmationDialog(
            "Send an SOS alert?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send SOS", role: .destructive) {
                trigger()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This shares your ride and location with an emergency contact.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: messageToShare)
        }
    }

    private func trigger() {
        messageToShare = SOSService.shared.emergencyMessage(
            userName: userName,
            rideId: rideId,
            coordinate: coordinate
        )
        showShareSheet = true
        Task {
            await SOSService.shared.logAlert(userId: userId, rideId: rideId, coordinate: coordinate)
        }
    }
}

/// Thin UIActivityViewController wrapper — SwiftUI's own ShareLink can't
/// share a plain pre-composed string quite this flexibly pre-iOS 17, and
/// this keeps the deployment target at Constants.App.minimumIOSVersion (16).
private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SOSButton(userName: "Alex", userId: "preview-uid", rideId: "preview-ride", coordinate: nil)
}
