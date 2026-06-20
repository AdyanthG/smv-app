//
//  ScoreProgressView.swift
//  SMV
//
//  Score history chart showing trend over time.
//

import SwiftUI
import Charts
import SwiftData

struct ScoreProgressView: View {

    @Environment(AuthService.self) private var auth
    @Query(sort: \ScanResult.timestamp) private var allResults: [ScanResult]

    private var scanResults: [ScanResult] {
        guard let uid = auth.currentUserId else { return allResults }
        return allResults.filter { $0.userId == uid }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SMVSpacing.xxl) {
                if scanResults.isEmpty {
                    emptyState
                } else {
                    summaryHeader
                    scoreChart
                    attributeTrends
                    scanHistoryList
                }
            }
            .padding(.horizontal, SMVSpacing.xxl)
            .padding(.top, SMVSpacing.xxl)
        }
        .background(Color.smvBackground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Summary

    private var summaryHeader: some View {
        HStack(spacing: SMVSpacing.xxl) {
            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                Text("CURRENT")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                    .tracking(1)
                Text(latestScore.scoreFormatted)
                    .font(SMVFont.scoreMedium())
                    .foregroundStyle(.white)
            }

            if scanResults.count > 1 {
                VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                    Text("CHANGE")
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)
                        .tracking(1)
                    Text(scoreDelta.deltaFormatted)
                        .font(SMVFont.scoreMedium())
                        .foregroundStyle(scoreDelta >= 0 ? Color.smvEmerald : Color.smvPink)
                }
            }

            VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                Text("SCANS")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                    .tracking(1)
                Text("\(scanResults.count)")
                    .font(SMVFont.scoreMedium())
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    // MARK: - Chart

    private var scoreChart: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: SMVSpacing.md) {
                Text("SCORE TREND")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)
                    .tracking(1)

                Chart(scanResults) { result in
                    LineMark(
                        x: .value("Date", result.timestamp),
                        y: .value("Score", result.overallScore)
                    )
                    .foregroundStyle(Color.smvCyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", result.timestamp),
                        y: .value("Score", result.overallScore)
                    )
                    .foregroundStyle(Color.smvCyan)
                    .symbolSize(30)

                    AreaMark(
                        x: .value("Date", result.timestamp),
                        y: .value("Score", result.overallScore)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.smvCyan.opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 1...10)
                .chartYAxis {
                    AxisMarks(values: [2, 4, 6, 8, 10]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.smvSurface2)
                        AxisValueLabel()
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Attribute Trends

    private var attributeTrends: some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            Text("CATEGORY BREAKDOWN")
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .tracking(1)

            if let latest = scanResults.last {
                ForEach(latest.attributes, id: \.name) { attr in
                    HStack {
                        Text(attr.name)
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvTextSecondary)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.smvSurface2)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ScoreTier.from(score: attr.score).color)
                                    .frame(width: geo.size.width * attr.score / 10.0, height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text(attr.score.scoreFormatted)
                            .font(SMVFont.monoSmall())
                            .foregroundStyle(.white)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Scan History

    private var scanHistoryList: some View {
        VStack(alignment: .leading, spacing: SMVSpacing.md) {
            Text("SCAN HISTORY")
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .tracking(1)

            ForEach(scanResults.reversed().prefix(10), id: \.id) { result in
                HStack {
                    VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                        Text(result.timestamp, format: .dateTime.month().day().year())
                            .font(SMVFont.caption())
                            .foregroundStyle(.white)
                        Text(result.tier.rawValue)
                            .font(SMVFont.micro())
                            .foregroundStyle(Color.smvTextTertiary)
                    }
                    Spacer()
                    Text(result.overallScore.scoreFormatted)
                        .font(SMVFont.monoSmall())
                        .foregroundStyle(result.tier.color)
                }
                .padding(.vertical, SMVSpacing.sm)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(Color.smvTextTertiary)
            Text("No scan data yet")
                .font(SMVFont.title())
                .foregroundStyle(Color.smvTextSecondary)
            Text("Complete your first scan to start tracking progress")
                .font(SMVFont.caption())
                .foregroundStyle(Color.smvTextTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var latestScore: Double {
        scanResults.last?.overallScore ?? 0
    }

    private var scoreDelta: Double {
        guard scanResults.count >= 2 else { return 0 }
        return scanResults.last!.overallScore - scanResults[scanResults.count - 2].overallScore
    }
}
