//
//  HapticService.swift
//  SMV
//
//  Centralized haptic feedback for premium feel.
//

import UIKit

@Observable
final class HapticService {

    // MARK: - Impact

    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    // MARK: - Notification

    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection

    func selection() {
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
