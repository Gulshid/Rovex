//
//  SplashView.swift
//  RideBookingApp
//
//  Phase 2 — Shown briefly while SessionManager checks Firebase Auth state.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Rovex")
                .font(.largeTitle.bold())
            ProgressView()
                .padding(.top, 8)
        }
    }
}

#Preview {
    SplashView()
}
