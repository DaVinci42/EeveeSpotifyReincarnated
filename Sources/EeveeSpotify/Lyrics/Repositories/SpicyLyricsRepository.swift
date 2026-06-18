import Foundation

// MARK: - SpicyLyricsRepository
//
// Fetches lyrics from api.spicylyrics.org (the SpicyLyrics / nontitled backend)
// and converts the response into EeveeSpotify's LyricsDto.
//
// The API is identical to what the Spicetify extension uses:
//   POST https://api.spicylyrics.org/query
//   Body: { queries: [{ operation: "lyrics", variables: { id: <trackId>, auth: "<headerName>" } }],
//           client: { version: "..." } }
//   Header: "<headerName>": "Bearer <spotifyToken>"
//
// The `data` field in each query result is an SLObjPack-encoded value (a two-element
// JSON array [valuesList, stream]) which we decode with SLObjPack.swift.
//
// Supported lyrics types: "Syllable" (word-level karaoke), "Line" (timestamp per line),
// "Static" (no timestamps). Because EeveeSpotify's LyricsDto only supports line-level
// timing, Syllable lyrics are collapsed — we join syllables and use the lead StartTime.

class SpicyLyricsRepository: LyricsRepository {

    static let shared = SpicyLyricsRepository()
    private init() {}

    private static let apiUrl        = "https://api.spicylyrics.org"
    private static let authHeaderKey = "SpicyLyrics-WebAuth"       // name sent in variables.auth
    private static let clientVersion = "EeveeSpotify/1.0"

    // MARK: - Network

    private func performQuery(trackId: String) throws -> Data {
        guard let url = URL(string: "\(SpicyLyricsRepository.apiUrl)/query") else {
            throw LyricsError.decodingError
        }

        // Build the request body exactly as the JS extension does.
        let body: [String: Any] = [
            "queries": [
                [
                    "operation": "lyrics",
                    "variables": [
                        "id":   trackId,
                        "auth": SpicyLyricsRepository.authHeaderKey
                    ]
                ]
            ],
            "client": [
                "version": SpicyLyricsRepository.clientVersion
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            SpicyLyricsRepository.clientVersion,
            forHTTPHeaderField: "SpicyLyrics-Version"
        )

        // Pass the captured Spotify Bearer token under the key named in variables.auth.
        if let token = spotifyAccessToken {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: SpicyLyricsRepository.authHeaderKey
            )
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?

        URLSession.shared.dataTask(with: request) { data, _, error in
            responseData = data
            responseError = error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        if let error = responseError {
            writeDebugLog("[SpicyLyrics] Network error for \(trackId): \(error)")
            throw error
        }
        guard let data = responseData else {
            writeDebugLog("[SpicyLyrics] No data for \(trackId)")
            throw LyricsError.decodingError
        }
        writeDebugLog("[SpicyLyrics] Received \(data.count) bytes for track \(trackId)")
        return data
    }

    // MARK: - Parse

    private func parseLyricsData(_ data: Data, trackId: String) throws -> LyricsDto {

        // Decode the outer JSON envelope.
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let queriesRaw = json["queries"] as? [[String: Any]],
            let firstQuery = queriesRaw.first,
            let result = firstQuery["result"] as? [String: Any]
        else {
            writeDebugLog("[SpicyLyrics] Malformed envelope for \(trackId)")
            throw LyricsError.decodingError
        }

        let httpStatus = result["httpStatus"] as? Int ?? 0

        switch httpStatus {
        case 404:
            throw LyricsError.noSuchSong
        case 200:
            break
        default:
            writeDebugLog("[SpicyLyrics] Unexpected status \(httpStatus) for \(trackId)")
            throw LyricsError.noSuchSong
        }

        guard let rawData = result["data"] else {
            throw LyricsError.decodingError
        }

        // Decode the SLObjPack payload.
        let packed: SLObjPackValue
        do {
            packed = try SLObjPack.unpack(rawData)
        } catch {
            writeDebugLog("[SpicyLyrics] SLObjPack decode error for \(trackId): \(error)")
            throw LyricsError.decodingError
        }

        guard let type = packed["Type"]?.stringValue else {
            writeDebugLog("[SpicyLyrics] Missing Type field for \(trackId)")
            throw LyricsError.decodingError
        }

        writeDebugLog("[SpicyLyrics] Lyrics type for \(trackId): \(type)")

        switch type {
        case "Syllable": return parseSyllableLyrics(packed)
        case "Line":     return parseLineLyrics(packed)
        case "Static":   return parseStaticLyrics(packed)
        default:
            writeDebugLog("[SpicyLyrics] Unknown lyrics type '\(type)' for \(trackId)")
            throw LyricsError.decodingError
        }
    }

    // MARK: Syllable lyrics
    //
    // SpicyLyrics schema (Type == "Syllable"):
    //   Content: [{ Type: "Vocal", Lead: { Syllables: [{Text, StartTime, EndTime, ...}],
    //              StartTime, EndTime, OppositeAligned } }]
    //
    // Each top-level Content entry is one lyrics line.
    // We join its syllable Text values and use the Lead's StartTime as the line offset.

    private func parseSyllableLyrics(_ root: SLObjPackValue) -> LyricsDto {
        guard let content = root["Content"]?.arrayValue else { return emptyDto() }

        var lines        = [LyricsLineDto]()
        var hasRomanized = root["HasTransliterations"]?.boolValue ?? false

        for entry in content {
            guard
                entry["Type"]?.stringValue == "Vocal",
                let lead = entry["Lead"]?.objectValue.map({ SLObjPackValue.object($0) }) ?? entry["Lead"]
            else { continue }

            // Join syllable texts into one line string.
            let lineText: String
            if let syllables = lead["Syllables"]?.arrayValue, !syllables.isEmpty {
                lineText = syllables.compactMap { $0["Text"]?.stringValue }.joined()

                // If any syllable already carries a transliteration, flag it.
                let hasAnyTranslit = syllables.contains {
                    ($0["TransliteratedText"]?.stringValue ?? "").isEmpty == false
                }
                if hasAnyTranslit { hasRomanized = true }
            } else if let text = lead["Text"]?.stringValue {
                lineText = text
            } else {
                continue
            }

            if (lead["TransliteratedText"]?.stringValue ?? "").isEmpty == false {
                hasRomanized = true
            }

            let offsetMs = lead["StartTime"]?.doubleValue.map { Int($0 * 1000) }
            lines.append(LyricsLineDto(content: lineText.lyricsNoteIfEmpty, offsetMs: offsetMs))
        }

        return LyricsDto(
            lines: lines,
            timeSynced: true,
            romanization: hasRomanized
                ? .romanized
                : (lines.map(\.content).canBeRomanized ? .canBeRomanized : .original)
        )
    }

    // MARK: Line lyrics
    //
    // SpicyLyrics schema (Type == "Line"):
    //   Content: [{ Type: "Vocal", Lead?: { Text, StartTime, EndTime },
    //              Text?, StartTime?, EndTime? }]

    private func parseLineLyrics(_ root: SLObjPackValue) -> LyricsDto {
        guard let content = root["Content"]?.arrayValue else { return emptyDto() }

        var lines        = [LyricsLineDto]()
        let hasRomanized = root["HasTransliterations"]?.boolValue ?? false

        for entry in content {
            guard entry["Type"]?.stringValue == "Vocal" else { continue }

            // Text can live on Lead or directly on the entry.
            let text = entry["Lead"]?["Text"]?.stringValue
                    ?? entry["Text"]?.stringValue
                    ?? ""

            let startTime = entry["Lead"]?["StartTime"]?.doubleValue
                         ?? entry["StartTime"]?.doubleValue

            let offsetMs = startTime.map { Int($0 * 1000) }
            lines.append(LyricsLineDto(content: text.lyricsNoteIfEmpty, offsetMs: offsetMs))
        }

        return LyricsDto(
            lines: lines,
            timeSynced: true,
            romanization: hasRomanized
                ? .romanized
                : (lines.map(\.content).canBeRomanized ? .canBeRomanized : .original)
        )
    }

    // MARK: Static lyrics
    //
    // SpicyLyrics schema (Type == "Static"):
    //   Lines: [{ Text: string }]

    private func parseStaticLyrics(_ root: SLObjPackValue) -> LyricsDto {
        let rawLines = root["Lines"]?.arrayValue ?? []
        let lines = rawLines.compactMap { entry -> LyricsLineDto? in
            guard let text = entry["Text"]?.stringValue else { return nil }
            return LyricsLineDto(content: text.lyricsNoteIfEmpty, offsetMs: nil)
        }
        return LyricsDto(
            lines: lines,
            timeSynced: false,
            romanization: lines.map(\.content).canBeRomanized ? .canBeRomanized : .original
        )
    }

    private func emptyDto() -> LyricsDto {
        LyricsDto(lines: [], timeSynced: false, romanization: .original)
    }

    // MARK: - LyricsRepository

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        let trackId = query.spotifyTrackId
        guard !trackId.isEmpty else {
            writeDebugLog("[SpicyLyrics] Empty track ID")
            throw LyricsError.noSuchSong
        }
        let data = try performQuery(trackId: trackId)
        return try parseLyricsData(data, trackId: trackId)
    }
}
