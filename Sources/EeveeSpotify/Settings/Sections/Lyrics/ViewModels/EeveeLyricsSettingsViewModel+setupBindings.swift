import SwiftUI
import Combine

extension EeveeLyricsSettingsViewModel {
    func setupBindings() {
        $lyricsOptions
            .map(\.musixmatchLanguage)
            .sink { [weak self] language in
                guard let self = self else { return }
                
                let isValidLanguage = language.isEmpty || language ~= "^[\\w\\d]{2}$"
                
                if isValidLanguage {
                    self.showMusixmatchInvalidLanguageWarning = false
                    MusixmatchLyricsRepository.shared.selectedLanguage = language
                    return
                }
                
                self.showMusixmatchInvalidLanguageWarning = true
            }
            .store(in: &cancellables)
        
        $lyricsOptions
            .map(\.lrclibUrl)
            .map { urlString -> AnyPublisher<LrclibURLState, Never> in
                guard let url = URL(string: urlString) else {
                    return Just(.invalidURL).eraseToAnyPublisher()
                }
                
                if url.host == "lrclib.net" {
                    return Just(.originalURL).eraseToAnyPublisher()
                }
                
                return URLSession.shared.dataTaskPublisher(for: url)
                    .map { _ in
                        LrclibLyricsRepository.shared.apiUrl = urlString
                        return LrclibURLState.ok
                    }
                    .catch { _ in Just(LrclibURLState.unreachableURL) }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$lrclibURLState)
        
        $musixmatchToken
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tokenString in
                guard let self = self else { return }
                
                if let token = self.getMusixmatchTokenFromDebugInfo(tokenString) {
                    self.musixmatchToken = token
                    return
                }
                
                if let token = self.getMusixmatchToken(tokenString) {
                    UserDefaults.musixmatchToken = token
                }
            }
            .store(in: &cancellables)
        
        $lyricsSource
            .dropFirst()
            .sink { [weak self] newSource in
                guard let self = self else { return }
                
                if newSource == .musixmatch && self.musixmatchToken.isEmpty {
                    // Token field is always visible in UI - no alert needed
                }
                
                if newSource == .lrclib {
                    self.lyricsOptions.lrclibUrl = LrclibLyricsRepository.originalApiUrl
                }
                
                UserDefaults.lyricsSource = newSource

                // Signal the lyrics URL hook to bust its caches on the next
                // intercept so the new source is used without an app restart.
                lyricsSourceDidChange = true
                MusixmatchLyricsRepository.shared.clearCache()
                capturedTrackId = nil
                capturedTrackTitle = nil
                capturedArtistName = nil

                // Evict any color-lyrics responses that Spotify cached in
                // NSURLCache. Without this, already-played tracks are served
                // from the HTTP cache and our hook never fires — meaning the
                // old source's lyrics are shown until an app restart.
                // removeCachedResponses(since: .distantPast) clears everything,
                // which is acceptable since we only call this on explicit user action.
                URLCache.shared.removeCachedResponses(since: .distantPast)

                // Ask Spotify to re-fetch lyrics by nudging the scroll view.
                // The collection view reload causes the LyricsScrollProvider to
                // request the color-lyrics URL again, which our hook intercepts.
                DispatchQueue.main.async {
                    if let vc = nowPlayingScrollViewController {
                        vc.collectionView().reloadData()
                    } else if let vc = npvScrollViewController {
                        vc.collectionView().reloadData()
                    }
                }
            }
            .store(in: &cancellables)
    }
}
