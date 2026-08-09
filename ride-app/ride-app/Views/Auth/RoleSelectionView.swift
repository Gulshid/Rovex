//
//  RoleSelectionView.swift
//  RideBookingApp
//
//  Phase 2 — Lets a new user choose Rider or Driver before filling out the
//  sign-up form. The chosen role is carried into SignUpView via AppRoute.
//

import SwiftUI

struct RoleSelectionView: View {

    @EnvironmentObject var router: Router

    var body: some View {
        VStack(spacing: 24) {
            Text("How will you use Rovex?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                roleCard(
                    role: .rider,
                    title: "I need a ride",
                    subtitle: "Book rides and get where you're going",
                    icon: "person.fill"
                )
                roleCard(
                    role: .driver,
                    title: "I want to drive",
                    subtitle: "Accept ride requests and earn",
                    icon: "car.fill"
                )
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Get Started")
    }

    private func roleCard(role: UserRole, title: String, subtitle: String, icon: String) -> some View {
        Button {
            router.push(.signUp(role: role))
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { RoleSelectionView() }
        .environmentObject(Router())
}
