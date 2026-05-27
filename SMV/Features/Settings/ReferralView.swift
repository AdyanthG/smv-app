//
//  ReferralView.swift
//  SMV
//
//  Referral system: invite friends, earn premium.
//  3 referrals = 1 month free SMV Pro.
//

import SwiftUI

struct ReferralView: View {

    @Environment(AuthService.self) private var auth
    @Environment(FirestoreService.self) private var firestore
    @Environment(HapticService.self) private var haptics

    @State private var referralCode: String = ""
    @State private var referralCount: Int = 0
    @State private var isLoading = true
    @State private var showCopied = false

    private let requiredReferrals = 3

    var body: some View {
        ScrollView {
            VStack(spacing: SMVSpacing.xxl) {
                // Header
                VStack(spacing: SMVSpacing.md) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient.brandPrimary
                        )

                    Text("Invite Friends")
                        .font(SMVFont.displaySmall())
                        .foregroundStyle(.white)

                    Text("Share SMV with friends and earn free premium")
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, SMVSpacing.xxl)

                // Progress
                VStack(spacing: SMVSpacing.lg) {
                    HStack(spacing: SMVSpacing.lg) {
                        ForEach(0..<requiredReferrals, id: \.self) { index in
                            VStack(spacing: SMVSpacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(index < referralCount
                                            ? Color.smvEmerald.opacity(0.2)
                                            : Color.smvSurface2)
                                        .frame(width: 56, height: 56)

                                    Image(systemName: index < referralCount ? "checkmark" : "person.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(index < referralCount
                                            ? Color.smvEmerald
                                            : Color.smvTextTertiary)
                                }

                                Text("Friend \(index + 1)")
                                    .font(SMVFont.micro())
                                    .foregroundStyle(Color.smvTextSecondary)
                            }
                        }
                    }

                    Text("\(referralCount)/\(requiredReferrals) referrals")
                        .font(SMVFont.caption())
                        .foregroundStyle(Color.smvTextSecondary)

                    if referralCount >= requiredReferrals {
                        HStack(spacing: SMVSpacing.sm) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.smvAmber)
                            Text("You earned 1 month of SMV Pro!")
                                .font(SMVFont.title())
                                .foregroundStyle(Color.smvAmber)
                        }
                        .padding(SMVSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SMVRadius.md)
                                .fill(Color.smvAmber.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: SMVRadius.md)
                                        .stroke(Color.smvAmber.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)

                // Referral Code Card
                GlassmorphicCard(padding: SMVSpacing.lg) {
                    VStack(spacing: SMVSpacing.md) {
                        Text("Your Referral Code")
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)

                        if isLoading {
                            ProgressView()
                                .tint(Color.smvCyan)
                        } else {
                            Text(referralCode)
                                .font(SMVFont.headline())
                                .foregroundStyle(.white)
                                .kerning(3)
                        }

                        HStack(spacing: SMVSpacing.md) {
                            Button {
                                UIPasteboard.general.string = referralCode
                                haptics.success()
                                withAnimation { showCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopied = false }
                                }
                            } label: {
                                HStack(spacing: SMVSpacing.xs) {
                                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                    Text(showCopied ? "Copied!" : "Copy")
                                }
                                .font(SMVFont.caption())
                                .foregroundStyle(showCopied ? Color.smvEmerald : Color.smvCyan)
                                .padding(.horizontal, SMVSpacing.lg)
                                .padding(.vertical, SMVSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill((showCopied ? Color.smvEmerald : Color.smvCyan).opacity(0.1))
                                )
                            }

                            ShareLink(
                                item: "Join SMV and scan your face! Use my code \(referralCode) to sign up: https://smv.app/invite/\(referralCode)"
                            ) {
                                HStack(spacing: SMVSpacing.xs) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share")
                                }
                                .font(SMVFont.caption())
                                .foregroundStyle(Color.smvViolet)
                                .padding(.horizontal, SMVSpacing.lg)
                                .padding(.vertical, SMVSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(Color.smvViolet.opacity(0.1))
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)

                // How it works
                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    Text("How It Works")
                        .font(SMVFont.title())
                        .foregroundStyle(.white)

                    stepRow(number: 1, text: "Share your unique referral code with friends")
                    stepRow(number: 2, text: "They sign up and enter your code")
                    stepRow(number: 3, text: "Get 3 friends to join → earn 1 month SMV Pro free")
                }
                .padding(.horizontal, SMVSpacing.lg)
            }
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Invite Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if let userId = auth.currentUserId {
                referralCode = await firestore.getReferralCode(userId: userId)
                referralCount = await firestore.getReferralCount(userId: userId)
                isLoading = false
            }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: SMVSpacing.md) {
            Text("\(number)")
                .font(SMVFont.title())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.smvSurface2))

            Text(text)
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
        }
    }
}
