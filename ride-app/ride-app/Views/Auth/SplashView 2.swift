//
//  SplashView.swift
//  RideBookingApp
//
//  Phase 2 — Shown briefly while SessionManager checks Firebase Auth state.
//
//  UPDATED — Branded splash screen: gradient backdrop, a badge-style logo
//  mark that scales/rotates in, staged text reveal, and a lightweight
//  three-dot loader instead of a bare system ProgressView. Everything here
//  is plain SwiftUI (no new asset files), so it drops in with no project
//  changes beyond this file.
//

import SwiftUI

struct SplashView: View {

    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -8
    @State private var ringOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.85
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10
    @State private var taglineOpacity: Double = 0
    @State private var loaderOpacity: Double = 0

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            glow
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                logoMark

                VStack(spacing: 8) {
                    Text("Rovex")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    Text("Your ride, on the way")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .opacity(taglineOpacity)
                }

                Spacer()

                ThreeDotLoader()
                    .opacity(loaderOpacity)
                    .padding(.bottom, 56)
            }
        }
        .onAppear(perform: animateIn)
    }

    // MARK: - Pieces

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.10, blue: 0.30),
                Color.accentColor.opacity(0.9),
                Color(red: 0.02, green: 0.06, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glow: some View {
        RadialGradient(
            colors: [Color.white.opacity(0.16), .clear],
            center: .center,
            startRadius: 10,
            endRadius: 260
        )
        .frame(width: 460, height: 460)
        .opacity(ringOpacity)
    }

    private var logoMark: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                .frame(width: 132, height: 132)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 104, height: 104)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

            Image(systemName: "car.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(logoRotation))
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
    }

    // MARK: - Animation sequencing

    private func animateIn() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.62)) {
            logoScale = 1.0
            logoOpacity = 1.0
            logoRotation = 0
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.05)) {
            ringOpacity = 1.0
            ringScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.55)) {
            taglineOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.75)) {
            loaderOpacity = 1.0
        }
    }
}

/// Small three-dot "breathing" loader used in place of a plain spinner —
/// reads as calmer/more branded against the gradient background.
private struct ThreeDotLoader: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .opacity(animate ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    SplashView()
}
