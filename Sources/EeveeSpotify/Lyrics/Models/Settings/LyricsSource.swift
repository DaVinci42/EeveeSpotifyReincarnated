// MODIFIED FILE: Sources/EeveeSpotify/Lyrics/Models/Settings/LyricsSource.swift
//
// Changes from original:
//   • Added `.spicylyrics` case (raw value 5)
//   • Added it to allCases so it appears in the Picker
//   • Added its description string
//
// Everything else is unchanged from the original.

import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case genius
    case lrclib
    case musixmatch
    case petit
    case notReplaced
    case spicylyrics   // NEW — raw value 5

    public static var allCases: [LyricsSource] {
        // Order determines display order in the Settings picker.
        // SpicyLyrics is listed first because it provides the richest
        // (syllable-level karaoke) data when the track is in their catalogue.
        return [.spicylyrics, .musixmatch, .lrclib, .genius, .petit]
    }

    var description: String {
        switch self {
        case .genius:       return "Genius"
        case .lrclib:       return "LRCLIB"
        case .musixmatch:   return "Musixmatch"
        case .petit:        return "PetitLyrics"
        case .notReplaced:  return "Spotify"
        case .spicylyrics:  return "SpicyLyrics"   // NEW
        }
    }

    var isReplacingLyrics: Bool { self != .notReplaced }

    static var defaultSource: LyricsSource {
        .spicylyrics   // changed from .musixmatch — SpicyLyrics is now the default
    }
}
