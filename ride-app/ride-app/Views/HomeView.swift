//
//  HomeView.swift
//  RideBookingApp
//
//  Phase 3 — Now reflects the logged-in user and links to Profile.
//  Real map/booking UI arrives in Phase 6–7.
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router

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

            Button("View Profile") {
                router.push(.profile)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
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
