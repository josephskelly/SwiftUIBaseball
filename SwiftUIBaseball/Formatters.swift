//
//  Formatters.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import Foundation

/// Format an OPS value for display.
///
/// Values below 1.0 are shown as three-digit decimals (e.g. `.850`).
/// Values at or above 1.0 include the leading digit (e.g. `1.036`).
func formatOPS(_ ops: Double) -> String {
    if ops >= 1.0 {
        return String(format: "%.3f", ops)
    } else {
        return String(format: ".%03.0f", ops * 1000)
    }
}

/// Format a rate stat (AVG, OBP, SLG, OPS) as a `.xxx`-style string without a suffix.
///
/// Values below 1.0 are shown as three-digit decimals (e.g. `.310`).
/// Values at or above 1.0 include the leading digit (e.g. `1.036`).
func formatRate(_ value: Double) -> String {
    if value >= 1.0 {
        return String(format: "%.3f", value)
    } else {
        return String(format: ".%03.0f", value * 1000)
    }
}

/// Format an innings pitched value for display (e.g. `162.0` → `"162.0"`).
func formatIP(_ ip: Double) -> String {
    String(format: "%.1f", ip)
}

/// Format a percentage value (0–1 scale) as a whole-number percent, e.g. `0.45` → `"45%"`.
///
/// Returns `"—"` when the input is `nil`.
func formatPercent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f%%", value * 100)
}

/// Format a velocity value (mph) with one decimal, e.g. `92.3` → `"92.3"`.
///
/// Returns `"—"` when the input is `nil`.
func formatVelocity(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.1f", value)
}

/// Format a launch angle (degrees) with one decimal and a degree sign, e.g. `12.4` → `"12.4°"`.
///
/// Returns `"—"` when the input is `nil`.
func formatAngle(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.1f°", value)
}

/// Format a spin rate (RPM) as a whole number, e.g. `2431.0` → `"2431"`.
///
/// Returns `"—"` when the input is `nil`.
func formatSpinRate(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f", value)
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
