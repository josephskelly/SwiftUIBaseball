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

/// Name suffixes that should not be treated as a last name.
private let nameSuffixes: Set<String> = ["Jr.", "Sr.", "II", "III", "IV", "V"]

/// Split a full name into (core parts, suffix) where suffix is a trailing
/// generational token like "Jr." or "III", if present.
///
/// - Parameter fullName: A player's full display name.
/// - Returns: A tuple of the name parts without the suffix and the suffix string (empty if none).
func splitNameSuffix(_ fullName: String) -> (core: [Substring], suffix: String) {
    let parts = fullName.split(separator: " ")
    if let last = parts.last, nameSuffixes.contains(String(last)) {
        return (Array(parts.dropLast()), String(last))
    }
    return (parts, "")
}

/// Extract the family name from a full name, ignoring generational suffixes.
///
/// Returns the last word that is not a suffix (e.g. "Jr.", "III").
/// Falls back to the full string when parsing fails.
func familyName(_ fullName: String) -> String {
    let (core, _) = splitNameSuffix(fullName)
    return core.last.map(String.init) ?? fullName
}

/// Abbreviate a player's full name to "F. Last" (or "F. Last Jr." when a suffix is present).
///
/// Handles generational suffixes so that "Fernando Tatis Jr." becomes "F. Tatis Jr."
/// rather than "F. Jr.". Single-word names are returned unchanged.
func abbreviatedName(_ fullName: String) -> String {
    let (core, suffix) = splitNameSuffix(fullName)
    guard let first = core.first, let last = core.last, core.count > 1 else {
        return fullName
    }
    let base = "\(first.prefix(1)). \(last)"
    return suffix.isEmpty ? base : "\(base) \(suffix)"
}
