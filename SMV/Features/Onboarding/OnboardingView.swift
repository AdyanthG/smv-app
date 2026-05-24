//
//  OnboardingView.swift
//  SMV
//
//  Multi-page onboarding with animated transitions.
//

import SwiftUI

struct OnboardingView: View {

    @State private var currentPage = 0
    @Environment(AuthService.self) private var auth
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "bolt.fill",
            title: "Know Your Edge",
            subtitle: "AI-powered facial analysis using 76 landmark points. Get your real SMV score in seconds.",
            gradient: [.smvViolet, .smvCyan]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Glow Up",
            subtitle: "Watch your score improve over time with detailed attribute breakdowns and personalized tips.",
            gradient: [.smvCyan, .smvEmerald]
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Join the Community",
            subtitle: "Share progress, compete on leaderboards, and learn from the looksmaxxing community.",
            gradient: [.smvEmerald, .smvAmber]
        ),
    ]

    var body: some View {
        ZStack {
            Color.smvBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation { currentPage = pages.count - 1 }
                        }
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextTertiary)
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.top, SMVSpacing.lg)
                .frame(height: 44)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator + CTA
                VStack(spacing: SMVSpacing.xxl) {
                    // Dots
                    HStack(spacing: SMVSpacing.sm) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.smvCyan : Color.smvSurface2)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    // CTA
                    if currentPage == pages.count - 1 {
                        VStack(spacing: SMVSpacing.md) {
                            GradientButton(title: "Get Started", icon: "arrow.right") {
                                haptics.success()
                                auth.completeOnboarding()
                                router.dismiss()
                            }

                            Button("Sign in with Apple") {
                                Task { await auth.signInWithApple() }
                                auth.completeOnboarding()
                                router.dismiss()
                            }
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)
                        }
                    } else {
                        GradientButton(title: "Next", icon: "arrow.right") {
                            haptics.selection()
                            withAnimation(.spring(duration: 0.4)) {
                                currentPage += 1
                            }
                        }
                    }
                }
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.bottom, SMVSpacing.huge)
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: SMVSpacing.xxxl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.15)
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).opacity(0.08)
                    )
                    .frame(width: 180, height: 180)

                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: SMVSpacing.lg) {
                Text(page.title)
                    .font(SMVFont.displayMedium())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SMVSpacing.xxl)
            }

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

#Preview {
    OnboardingView()
        .environment(AuthService())
        .environment(Router())
        .environment(HapticService())
}
