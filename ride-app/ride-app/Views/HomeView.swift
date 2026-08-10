//
//  HomeView.swift
//  RideBookingApp
//
//  Phase 3 — Now reflects the logged-in user and links to Profile.
//  Phase 6/7 — Riders get a "Book a Ride" entry point into the live map
//  / booking flow. Drivers get their online/request-matching UI in
//  Phase 8, so for now they just see a placeholder note.
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router

    private var isRider: Bool {
        sessionManager.currentUser?.role != .driver
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome, \(sessionManager.currentUser?.name ?? "")")
                .font(.title2.bold())

            Text(sessionManager.currentUser?.role == .driver ? "Driver mode" : "Rider mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isRider {
                Button {
                    router.push(.mapBooking)
                } label: {
                    Label("Book a Ride", systemImage: "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            } else {
                Text("Driver request matching arrives in Phase 8.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Button("View Profile") {
                router.push(.profile)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Home")
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
