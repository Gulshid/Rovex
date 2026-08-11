//
//  HomeView.swift
//  RideBookingApp
//
//  Phase 3 — Now reflects the logged-in user and links to Profile.
//  Phase 6/7 — Riders get a "Book a Ride" entry point into the live map
//  / booking flow.
//  Phase 8 — Drivers now get a "Go Online" entry point into DriverHomeView
//  (online/offline toggle + incoming ride requests), replacing the old
//  placeholder note.
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
                Button {
                    router.push(.driverHome)
                } label: {
                    Label("Go Online", systemImage: "car.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
