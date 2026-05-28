//
//  OnboardingView.swift
//  SMV
//
//  Multi-page onboarding with animated transitions.
//

import SwiftUI

struct OnboardingView: View {

    @State private var currentPage = 0
    @State private var nameInput = ""
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
                            // Name entry
                            TextField("Your name", text: $nameInput)
                                .font(SMVFont.body())
                                .foregroundStyle(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.smvSurface1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.smvSurface2, lineWidth: 1)
                                        )
                                )
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()

                            // Get Started button
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(height: 50)
                            } else {
                                GradientButton(
                                    title: nameInput.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? "Enter your name" : "Get Started",
                                    icon: "arrow.right"
                                ) {
                                    let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                                    guard !trimmed.isEmpty else { return }
                                    haptics.success()
                                    Task {
                                        await auth.signInAnonymouslyWithName(trimmed)
                                        if auth.currentUserId != nil {
                                            auth.completeOnboarding()
                                            router.dismiss()
                                        }
                                    }
                                }
                                .opacity(nameInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                            }

                            if let error = auth.errorMessage {
                                Text(error)
                                    .font(SMVFont.micro())
                                    .foregroundStyle(Color.smvPink)
                                    .multilineTextAlignment(.center)
                            }

                            Text("Your name will appear on leaderboards and posts")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                                .multilineTextAlignment(.center)
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
