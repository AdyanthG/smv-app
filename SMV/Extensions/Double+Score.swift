//
//  Double+Score.swift
//  SMV
//
//  Score formatting and comparison utilities.
//

import Foundation

extension Double {

    /// "8.4"
    var scoreFormatted: String {
        String(format: "%.1f", self)
    }

    /// "+0.3" or "-0.2"
    var deltaFormatted: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", self))"
    }
}

extension Comparable {
    /// Clamp to a closed range
    func smvClamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Double {
    /// Normalize from one range to another
    func normalized(from source: ClosedRange<Double>, to target: ClosedRange<Double> = 0...1) -> Double {
        let sourceSpan = source.upperBound - source.lowerBound
        guard sourceSpan > 0 else { return target.lowerBound }
        let normalized = (self - source.lowerBound) / sourceSpan
        let targetSpan = target.upperBound - target.lowerBound
        return target.lowerBound + normalized * targetSpan
    }
}

