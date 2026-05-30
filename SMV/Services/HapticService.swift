//
//  HapticService.swift
//  SMV
//
//  Centralized haptic feedback for premium feel.
//

import UIKit

@Observable
final class HapticService {

    /// User preference (Settings → Haptic Feedback). Defaults to enabled.
    static let prefKey = "smv_hapticsEnabled"
    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.prefKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: Self.prefKey)
    }

    // MARK: - Impact

    func lightImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func mediumImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func heavyImpact() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // MARK: - Notification

    func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection

    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Compound Patterns

    /// Score reveal: escalating impacts
    func scoreReveal() {
        Task { @MainActor in
            for i in 0..<3 {
                try? await Task.sleep(for: .milliseconds(150))
                switch i {
                case 0: lightImpact()
                case 1: mediumImpact()
                default: heavyImpact()
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
            success()
        }
    }

    /// Achievement unlock: double tap
    func achievementUnlock() {
        Task { @MainActor in
            heavyImpact()
            try? await Task.sleep(for: .milliseconds(100))
            success()
        }
    }

    /// Tab switch: crisp selection
    func tabSwitch() {
        selection()
    }
}
