//
//  VoteView.swift
//  SMV
//
//  Infinite-scroll voting system where users compare two faces with
//  similar scores and vote on who looks better. Votes feed back
//  into leaderboard rankings as a tiebreaker.
//

import SwiftUI

struct VoteView: View {

    @Environment(FirestoreService.self) private var firestore
    @Environment(AuthService.self) private var auth
    @Environment(HapticService.self) private var haptics
    @Environment(Router.self) private var router

    @State private var userA: VoteCandidate?
    @State private var userB: VoteCandidate?
    @State private var isLoading = true
    @State private var selectedSide: VoteSide?
    @State private var voteCount = 0
    @State private var showEmpty = false
    @State private var myWins = 0
    @State private var myLosses = 0

    enum VoteSide { case left, right }

    private var myWinRate: Int {
        let total = myWins + myLosses
        guard total > 0 else { return 0 }
        return Int((Double(myWins) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Vote")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: SMVSpacing.xs) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                    Text("\(voteCount)")
                        .font(SMVFont.caption())
                }
                .foregroundStyle(Color.smvCyan)
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.top, SMVSpacing.sm)
            .padding(.bottom, SMVSpacing.xs)

            if isLoading && userA == nil {
                loadingState
            } else if showEmpty {
                emptyState
            } else if let a = userA, let b = userB {
                votingContent(a: a, b: b)
            }
        }
        .background(Color.smvBackground)
        .navigationBarHidden(true)
        .task {
            await loadMyRecord()
            await loadPair()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()
            ProgressView()
                .tint(Color.smvCyan)
                .scaleEffect(1.2)
            Text("Finding matchups...")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvTextTertiary)

            Text("Not Enough Users")
                .font(SMVFont.headline())
                .foregroundStyle(.white)

            Text("We need at least 2 users with scans\nto start voting. Invite friends!")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Voting Content

    private func votingContent(a: VoteCandidate, b: VoteCandidate) -> some View {
        VStack(spacing: SMVSpacing.lg) {
            // Header
            Text("Who looks better?")
                .font(SMVFont.headline())
                .foregroundStyle(.white)
                .padding(.top, SMVSpacing.lg)

            // VS Cards
            HStack(spacing: SMVSpacing.md) {
                voteCard(candidate: a, side: .left)
                    .onTapGesture { castVote(winner: .left) }

                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.smvTextTertiary)

                voteCard(candidate: b, side: .right)
                    .onTapGesture { castVote(winner: .right) }
            }
            .padding(.horizontal, SMVSpacing.md)

            // Skip
            Button {
                haptics.lightImpact()
                Task { await loadPair() }
            } label: {
                HStack(spacing: SMVSpacing.xs) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                    Text("Skip")
                        .font(SMVFont.caption())
                }
                .foregroundStyle(Color.smvTextTertiary)
                .padding(.horizontal, SMVSpacing.xxl)
                .padding(.vertical, SMVSpacing.sm)
                .background(
                    Capsule().fill(Color.smvSurface1)
                )
            }

            Spacer()

            // Your record + path to the Most Voted leaderboard (the goal loop)
            VStack(spacing: SMVSpacing.md) {
                Text("Tap the person you think looks better")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)

                Button {
                    haptics.lightImpact()
                    router.switchTab(.leaderboard)
                } label: {
                    HStack(spacing: SMVSpacing.lg) {
                        recordStat(value: "\(myWins)", label: "Wins", color: .smvEmerald)
                        Divider().frame(height: 28).overlay(Color.smvSurface2)
                        recordStat(value: "\(myLosses)", label: "Losses", color: .smvPink)
                        Divider().frame(height: 28).overlay(Color.smvSurface2)
                        recordStat(value: "\(myWinRate)%", label: "Win Rate", color: .smvCyan)
                    }
                    .padding(.vertical, SMVSpacing.md)
                    .padding(.horizontal, SMVSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SMVRadius.md)
                            .fill(Color.smvSurface0)
                    )
                }
                .buttonStyle(.plain)

                Text("Your record — climb the Most Voted leaderboard →")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary.opacity(0.7))
            }
            .padding(.horizontal, SMVSpacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func recordStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SMVFont.title())
                .foregroundStyle(color)
            Text(label)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Vote Card

    private func voteCard(candidate: VoteCandidate, side: VoteSide) -> some View {
        let isSelected = selectedSide == side
        let isWinner = isSelected
        let isLoser = selectedSide != nil && !isSelected

        // Prefer the actual scan face; fall back to profile photo, then initial.
        let faceURL = candidate.frontImageURL ?? candidate.avatarURL

        return VStack(spacing: SMVSpacing.md) {
            // Face being judged (front scan image)
            Group {
                if let urlStr = faceURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        faceFallback(candidate)
                    }
                } else {
                    faceFallback(candidate)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: SMVRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: SMVRadius.md)
                    .stroke(
                        isWinner ? Color.smvEmerald :
                        isLoser ? Color.smvPink.opacity(0.5) :
                        Color.white.opacity(0.06),
                        lineWidth: isWinner ? 3 : 1
                    )
            )

            // Name
            Text(candidate.name)
                .font(SMVFont.title())
                .foregroundStyle(.white)
                .lineLimit(1)

            // Score badge
            let tier = ScoreTier.from(score: candidate.score)
            Text(candidate.score.scoreFormatted)
                .font(SMVFont.caption())
                .foregroundStyle(tier.color)
                .padding(.horizontal, SMVSpacing.md)
                .padding(.vertical, SMVSpacing.xs)
                .background(
                    Capsule().fill(tier.color.opacity(0.1))
                )

            // Vote result indicator
            if isWinner {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                    Text("Winner")
                        .font(SMVFont.micro())
                }
                .foregroundStyle(Color.smvEmerald)
            } else if isLoser {
                Text("—")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SMVSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: SMVRadius.lg)
                .fill(Color.smvSurface0)
                .overlay(
                    RoundedRectangle(cornerRadius: SMVRadius.lg)
                        .stroke(
                            isWinner ? Color.smvEmerald.opacity(0.3) :
                            Color.white.opacity(0.04),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isWinner ? 1.02 : isLoser ? 0.98 : 1.0)
        .opacity(isLoser ? 0.6 : 1.0)
        .animation(.spring(duration: 0.3), value: selectedSide)
    }

    // MARK: - Actions

    private func castVote(winner: VoteSide) {
        guard selectedSide == nil else { return } // Prevent double-tap
        guard let a = userA, let b = userB else { return }
        guard let myId = auth.currentUserId else { return }

        haptics.success()
        selectedSide = winner

        let winnerId = winner == .left ? a.userId : b.userId
        let loserId = winner == .left ? b.userId : a.userId

        voteCount += 1

        Task {
            await firestore.recordVote(winnerId: winnerId, loserId: loserId, voterId: myId)

            // Brief pause to show result, then load next pair
            try? await Task.sleep(for: .seconds(0.8))
            selectedSide = nil
            await loadPair()
        }
    }

    private func faceFallback(_ candidate: VoteCandidate) -> some View {
        Rectangle()
            .fill(Color.smvSurface2)
            .overlay(
                Text(candidate.name.prefix(1).uppercased())
                    .font(SMVFont.displayMedium())
                    .foregroundStyle(Color.smvCyan)
            )
    }

    private func loadPair() async {
        isLoading = true
        let myId = auth.currentUserId ?? ""

        let (a, b) = await firestore.fetchVotePair(excludeUserId: myId)

        if let a, let b {
            var candA = VoteCandidate(
                userId: a["id"] as? String ?? "",
                name: a["displayName"] as? String ?? "User",
                score: a["latestScore"] as? Double ?? 0,
                avatarURL: a["avatarURL"] as? String
            )
            var candB = VoteCandidate(
                userId: b["id"] as? String ?? "",
                name: b["displayName"] as? String ?? "User",
                score: b["latestScore"] as? Double ?? 0,
                avatarURL: b["avatarURL"] as? String
            )
            // Fetch each candidate's latest scan front image (the face to judge).
            candA.frontImageURL = await firestore.fetchLatestScanImages(userId: candA.userId)["front"]
            candB.frontImageURL = await firestore.fetchLatestScanImages(userId: candB.userId)["front"]
            userA = candA
            userB = candB
            showEmpty = false
        } else {
            showEmpty = true
        }

        isLoading = false
    }

    /// Load the signed-in user's win/loss record (how often others picked them).
    private func loadMyRecord() async {
        guard let myId = auth.currentUserId,
              let data = await firestore.fetchUserProfile(userId: myId) else { return }
        myWins = Int(FirestoreService.numericValue(data["voteWins"]))
        myLosses = Int(FirestoreService.numericValue(data["voteLosses"]))
    }
}

// MARK: - Vote Candidate

struct VoteCandidate: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let score: Double
    let avatarURL: String?
    var frontImageURL: String? = nil
}

#Preview {
    NavigationStack { VoteView() }
        .environment(FirestoreService())
        .environment(AuthService())
        .environment(HapticService())
        .environment(Router())
}
