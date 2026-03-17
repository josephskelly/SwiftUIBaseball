//
//  PreviewHelpers.swift
//  SwiftUIBaseball
//

#if DEBUG
import Foundation
import SwiftBaseball

// MARK: - Date-aware decoder for previews

private let previewDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: s) { return date }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: s) { return date }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "Cannot decode date: \(s)"
        )
    }
    return d
}()

// MARK: - ScheduleEntry mock

extension ScheduleEntry {
    /// A mock Yankees @ Red Sox scheduled game for use in previews.
    static let preview: ScheduleEntry = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(ScheduleEntry.self, from: Data("""
        {
            "gamePk": 1,
            "gameDate": "2025-04-01",
            "status": "Scheduled",
            "teams": {
                "away": {"team": {"id": 147, "name": "New York Yankees"}},
                "home": {"team": {"id": 111, "name": "Boston Red Sox"}}
            },
            "gameType": "R",
            "season": "2025"
        }
        """.utf8))
    }()
}
#endif
