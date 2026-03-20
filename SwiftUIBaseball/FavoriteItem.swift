//
//  FavoriteItem.swift
//  SwiftUIBaseball
//

import Foundation
import SwiftData
import SwiftBaseball

/// A user-favorited team or player, persisted via SwiftData.
///
/// Each favorite stores the MLB API entity ID, a display name, and
/// optional metadata (team name, position, jersey number) for players.
/// The ``kind`` discriminator separates teams from players so both can
/// live in a single SwiftData store with straightforward queries.
@Model
final class FavoriteItem {

    // MARK: - Kind

    /// Discriminator for the type of favorited entity.
    enum Kind: String, Codable {
        case team
        case player
    }

    // MARK: - Stored Properties

    /// Whether this favorite represents a team or a player.
    var kind: Kind

    /// The MLB Stats API identifier (team ID or player ID).
    @Attribute(.unique) var entityId: Int

    /// Human-readable display name (team name or player full name).
    var name: String

    /// Timestamp when the user added this favorite.
    var addedAt: Date

    /// The team the player belonged to when favorited (players only).
    var teamName: String?

    /// Position display name, e.g. "Right Fielder" (players only).
    var position: String?

    /// Raw position code for reconstructing a ``RosterEntry`` (players only).
    ///
    /// Stores the MLB position code (e.g. "1" for pitcher, "9" for right field)
    /// so a ``RosterEntry`` can be decoded from JSON when opening a player card
    /// from the favorites list.
    var positionCode: String?

    /// Jersey number string (players only).
    var jerseyNumber: String?

    // MARK: - Init

    /// Creates a new favorite item.
    ///
    /// - Parameters:
    ///   - kind: Whether this is a team or player favorite.
    ///   - entityId: The MLB API ID for the entity.
    ///   - name: Display name for the entity.
    ///   - teamName: Team name (players only).
    ///   - position: Position display name (players only).
    ///   - positionCode: Raw MLB position code (players only).
    ///   - jerseyNumber: Jersey number string (players only).
    init(
        kind: Kind,
        entityId: Int,
        name: String,
        teamName: String? = nil,
        position: String? = nil,
        positionCode: String? = nil,
        jerseyNumber: String? = nil
    ) {
        self.kind = kind
        self.entityId = entityId
        self.name = name
        self.teamName = teamName
        self.position = position
        self.positionCode = positionCode
        self.jerseyNumber = jerseyNumber
        self.addedAt = Date()
    }

    // MARK: - Queries

    /// Checks whether an entity is already in the favorites store.
    ///
    /// Uses `fetchCount` to avoid materializing the full object when only
    /// existence is needed.
    ///
    /// - Parameters:
    ///   - entityId: The MLB API ID to look up.
    ///   - context: The model context to query.
    /// - Returns: `true` if a ``FavoriteItem`` with the given ID exists.
    static func isFavorited(entityId: Int, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.entityId == entityId }
        )
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    /// Toggles a favorite: deletes if it exists, inserts if it doesn't.
    ///
    /// - Parameters:
    ///   - kind: The entity kind (team or player).
    ///   - entityId: The MLB API ID.
    ///   - name: Display name for the entity.
    ///   - teamName: Team name (players only).
    ///   - position: Position display name (players only).
    ///   - positionCode: Raw MLB position code (players only).
    ///   - jerseyNumber: Jersey number string (players only).
    ///   - context: The model context to mutate.
    /// - Returns: `true` if the item was added, `false` if removed.
    @discardableResult
    static func toggle(
        kind: Kind,
        entityId: Int,
        name: String,
        teamName: String? = nil,
        position: String? = nil,
        positionCode: String? = nil,
        jerseyNumber: String? = nil,
        in context: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.entityId == entityId }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            return false
        } else {
            let item = FavoriteItem(
                kind: kind, entityId: entityId, name: name,
                teamName: teamName, position: position,
                positionCode: positionCode, jerseyNumber: jerseyNumber
            )
            context.insert(item)
            return true
        }
    }

    // MARK: - RosterEntry Reconstruction

    /// Reconstructs a ``RosterEntry`` from the stored favorite data.
    ///
    /// Uses JSON decoding (same approach as ``PreviewHelpers``) because
    /// ``RosterEntry`` has no public initializer. Returns `nil` if the
    /// favorite is a team or if decoding fails.
    var asRosterEntry: RosterEntry? {
        guard kind == .player else { return nil }
        let jerseyField = jerseyNumber.map { "\"\($0)\"" } ?? "null"
        let posField = positionCode ?? "U"
        let json = """
        {
            "person": {"id": \(entityId), "fullName": "\(name)"},
            "jerseyNumber": \(jerseyField),
            "position": "\(posField)",
            "status": "Active"
        }
        """
        return try? JSONDecoder().decode(RosterEntry.self, from: Data(json.utf8))
    }
}
