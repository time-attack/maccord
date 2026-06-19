import Foundation
import Observation

/// Local per-user notes (Discord "Note" on a profile — client-side only).
@MainActor
@Observable
final class UserNotesStore {
    private(set) var notes: [UInt64: String] = [:]

    func note(for userID: UInt64) -> String { notes[userID] ?? "" }

    func set(_ text: String, for userID: UInt64) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { notes.removeValue(forKey: userID) }
        else { notes[userID] = trimmed }
    }
}
