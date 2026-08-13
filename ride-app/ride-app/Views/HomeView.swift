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
//  UPDATED in Phase 12 — added a "Ride History" entry point for both
//  roles, and calls RatingService.recomputeAndSaveOwnAverageRating on
//  appear so the signed-in user's AppUser.rating/ratingCount reflect any
//  ratings they've received since their last session (see RatingService's
//  header for why this self-write-on-load pattern is needed instead of
//  the rater updating it directly).
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

            Button {
                router.push(.rideHistory)
            } label: {
                Label("Ride History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("View Profile") {
                router.push(.profile)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Home")
        .task {
            if let uid = sessionManager.currentUser?.id {
                await RatingService.shared.recomputeAndSaveOwnAverageRating(uid: uid)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
