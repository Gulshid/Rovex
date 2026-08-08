//
//  HomeView.swift
//  RideBookingApp
//
//  Phase 1 — Placeholder Home screen so the app compiles and runs.
//  Real map/booking UI arrives in Phase 6–7.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Ride Booking App")
                .font(.title2.bold())

            Text("Phase 1 scaffold — architecture in place ✅")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Home")
    }
}

#Preview {
    HomeView()
}
