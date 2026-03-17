//
//  Formatters.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import Foundation

/// Format an OPS value for display.
///
/// Values below 1.0 are shown as three-digit decimals (e.g. `.850 OPS`).
/// Values at or above 1.0 include the leading digit (e.g. `1.036 OPS`).
func formatOPS(_ ops: Double) -> String {
    if ops >= 1.0 {
        return String(format: "%.3f OPS", ops)
    } else {
        return String(format: ".%03.0f OPS", ops * 1000)
    }
}

/// Abbreviate a player's full name to "F. Last".
///
/// Single-word names are returned unchanged.
func abbreviatedName(_ fullName: String) -> String {
    let parts = fullName.split(separator: " ")
    guard let first = parts.first, let last = parts.last, parts.count > 1 else {
        return fullName
    }
    return "\(first.prefix(1)). \(last)"
}
