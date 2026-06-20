//
//  CoachView.swift
//  SMV
//
//  Elite-only personalized Looksmax Coach. Builds a plan from the user's latest
//  scan; shows an upgrade upsell for non-Elite users.
//

import SwiftUI
import SwiftData

struct CoachView: View {

    @Environment(SubscriptionManager.self) private var subs
    @Environment(AuthService.self) private var auth
    @Environment(Router.self) private var router
    @Environment(HapticService.self) private var haptics

    @Query(sort: \ScanResult.timestamp, order: .reverse) private var allScans: [ScanResult]
    @State private var completed: Set<String> = []

    private var latestScan: ScanResult? {
        guard let uid = auth.currentUserId else { return allScans.first }
        return allScans.first { $0.userId == uid } ?? allScans.first
    }

    var body: some View {
        Group {
            if !subs.isElite {
                upsell
            } else if let scan = latestScan {
                planView(CoachPlan.generate(from: scan))
            } else {
                noScanState
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Plan

    private func planView(_ plan: CoachPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                    HStack(spacing: SMVSpacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.smvAmber)
                        Text(plan.headline)
                            .font(SMVFont.headline())
                            .foregroundStyle(.white)
                    }
                    Text(plan.assessment)
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextSecondary)
                        .lineSpacing(4)
                }

                section("YOUR FOCUS AREAS") {
                    VStack(spacing: SMVSpacing.md) {
                        ForEach(plan.focusAreas) { area in
                            focusCard(area)
                        }
                    }
                }

                section("QUICK WINS") {
                    VStack(spacing: SMVSpacing.sm) {
                        ForEach(plan.quickWins, id: \.self) { win in
                            checkRow(win)
                        }
                    }
                }

                section("DAILY ROUTINE") {
                    VStack(spacing: SMVSpacing.lg) {
                        ForEach(plan.routine) { sec in
                            VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                                HStack(spacing: SMVSpacing.sm) {
                                    Image(systemName: sec.icon).foregroundStyle(Color.smvCyan)
                                    Text(sec.title).font(SMVFont.title()).foregroundStyle(.white)
                                }
                                ForEach(sec.items, id: \.self) { item in
                                    checkRow(item)
                                }
                            }
                        }
                    }
                }

                section("90-DAY ROADMAP") {
                    VStack(spacing: SMVSpacing.md) {
                        ForEach(plan.roadmap) { phase in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phase.phase)
                                    .font(SMVFont.title())
                                    .foregroundStyle(Color.smvCyan)
                                Text(phase.detail)
                                    .font(SMVFont.caption())
                                    .foregroundStyle(Color.smvTextSecondary)
                                    .lineSpacing(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SMVSpacing.md)
                            .background(RoundedRectangle(cornerRadius: SMVRadius.md).fill(Color.smvSurface0))
                        }
                    }
                }

                Text("Re-scan weekly to track your progress. Beauty is multidimensional — this plan is a tool, not a verdict on your worth.")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                    .padding(.top, SMVSpacing.md)
            }
            .padding(SMVSpacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func focusCard(_ area: CoachFocusArea) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            HStack(spacing: SMVSpacing.sm) {
                Image(systemName: area.icon)
                    .foregroundStyle(ScoreTier.from(score: area.score).color)
                Text(area.attribute).font(SMVFont.title()).foregroundStyle(.white)
                Spacer()
                Text(area.score.scoreFormatted)
                    .font(SMVFont.caption())
                    .foregroundStyle(ScoreTier.from(score: area.score).color)
            }
            Text(area.why)
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextSecondary)
                .lineSpacing(3)
            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                ForEach(area.protocols, id: \.self) { proto in
                    HStack(alignment: .top, spacing: SMVSpacing.sm) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.smvCyan)
                            .padding(.top, 4)
                        Text(proto)
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 2)
            Text(area.timeline)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvAmber)
                .padding(.top, 2)
        }
        .padding(SMVSpacing.lg)
        .background(RoundedRectangle(cornerRadius: SMVRadius.lg).fill(Color.smvSurface0))
    }

    private func checkRow(_ text: String) -> some View {
        Button {
            haptics.lightImpact()
            if completed.contains(text) { completed.remove(text) } else { completed.insert(text) }
        } label: {
            HStack(alignment: .top, spacing: SMVSpacing.sm) {
                Image(systemName: completed.contains(text) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed.contains(text) ? Color.smvEmerald : Color.smvTextTertiary)
                Text(text)
                    .font(SMVFont.caption())
                    .foregroundStyle(completed.contains(text) ? Color.smvTextTertiary : Color.smvTextPrimary)
                    .strikethrough(completed.contains(text))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            Text(title)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .tracking(1)
            content()
        }
    }

    // MARK: - Upsell (non-Elite)

    private var upsell: some View {
        ScrollView {
            VStack(spacing: SMVSpacing.xl) {
                Spacer().frame(height: SMVSpacing.xxl)
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.smvAmber, .smvViolet], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(LinearGradient(colors: [.smvAmber, .smvViolet], startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                VStack(spacing: SMVSpacing.sm) {
                    Text("Your personal Looksmax Coach")
                        .font(SMVFont.headline())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Get a plan built from your own scan — prioritized focus areas, exact protocols, a daily routine, and a 90-day roadmap.")
                        .font(SMVFont.body())
                        .foregroundStyle(Color.smvTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, SMVSpacing.xl)

                VStack(alignment: .leading, spacing: SMVSpacing.md) {
                    upsellPoint("target", "Personalized focus areas from your weakest metrics")
                    upsellPoint("list.bullet.clipboard", "Exact, proven protocols for each")
                    upsellPoint("checklist", "A daily routine you can check off")
                    upsellPoint("map", "A 90-day roadmap")
                }
                .padding(.horizontal, SMVSpacing.xl)

                GradientButton(title: "Unlock with Elite", icon: "crown.fill") {
                    haptics.mediumImpact()
                    router.present(.paywall)
                }
                .padding(.horizontal, SMVSpacing.xl)
            }
            .padding(.bottom, 100)
        }
    }

    private func upsellPoint(_ icon: String, _ text: String) -> some View {
        HStack(spacing: SMVSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(Color.smvAmber)
                .frame(width: 24)
            Text(text)
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
            Spacer()
        }
    }

    private var noScanState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Image(systemName: "viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(Color.smvTextTertiary)
            Text("Scan first")
                .font(SMVFont.headline())
                .foregroundStyle(.white)
            Text("Your coach builds your plan from a scan. Take one to get started.")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SMVSpacing.xxl)
            GradientButton(title: "Scan Now", icon: "bolt.fill", isFullWidth: false) {
                router.switchTab(.scan)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
