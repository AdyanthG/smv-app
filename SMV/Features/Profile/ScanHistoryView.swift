//
//  ScanHistoryView.swift
//  SMV
//
//  Full scan history view showing all scans with 5-angle thumbnails.
//

import SwiftUI
import SwiftData

struct ScanHistoryView: View {

    @Environment(Router.self) private var router
    @Query(sort: \ScanResult.timestamp, order: .reverse) private var scans: [ScanResult]

    var body: some View {
        ScrollView {
            if scans.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: SMVSpacing.md) {
                    ForEach(scans) { scan in
                        scanRow(scan)
                    }
                }
                .padding(.horizontal, SMVSpacing.lg)
                .padding(.vertical, SMVSpacing.lg)
            }
        }
        .background(Color.smvBackground)
        .navigationTitle("All Scans")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SMVSpacing.lg) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 48))
                .foregroundStyle(Color.smvTextTertiary)
            Text("No Scans Yet")
                .font(SMVFont.headline())
                .foregroundStyle(.white)
            Text("Complete a scan to see your history here.")
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, SMVSpacing.xxl)
    }

    // MARK: - Scan Row

    private func scanRow(_ scan: ScanResult) -> some View {
        Button {
            router.push(.scanResults(scanId: scan.id))
        } label: {
            HStack(spacing: SMVSpacing.md) {
                // Front image thumbnail
                if let data = scan.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: SMVRadius.sm))
                } else {
                    RoundedRectangle(cornerRadius: SMVRadius.sm)
                        .fill(ScoreTier.from(score: scan.overallScore).color.opacity(0.15))
                        .frame(width: 56, height: 70)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.smvTextTertiary)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: SMVSpacing.xs) {
                    HStack {
                        Text(scan.overallScore.scoreFormatted)
                            .font(SMVFont.headline())
                            .foregroundStyle(.white)

                        let tier = ScoreTier.from(score: scan.overallScore)
                        Text(tier.rawValue)
                            .font(SMVFont.micro())
                            .foregroundStyle(tier.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(tier.color.opacity(0.1)))
                    }

                    Text(scan.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(SMVFont.micro())
                        .foregroundStyle(Color.smvTextTertiary)

                    // Angle indicators
                    if scan.isMultiAngleScan {
                        HStack(spacing: 4) {
                            angleIndicator("F", data: scan.imageData)
                            angleIndicator("L", data: scan.leftImageData)
                            angleIndicator("R", data: scan.rightImageData)
                            angleIndicator("U", data: scan.upImageData)
                            angleIndicator("D", data: scan.downImageData)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.smvTextTertiary)
            }
            .padding(SMVSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SMVRadius.md)
                    .fill(Color.smvSurface0)
            )
        }
        .buttonStyle(.plain)
    }

    private func angleIndicator(_ label: String, data: Data?) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(data != nil ? Color.smvCyan : Color.smvTextTertiary.opacity(0.5))
            .frame(width: 18, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(data != nil ? Color.smvCyan.opacity(0.1) : Color.smvSurface1)
            )
    }
}

#Preview {
    NavigationStack {
        ScanHistoryView()
    }
    .environment(Router())
    .modelContainer(for: ScanResult.self, inMemory: true)
}
