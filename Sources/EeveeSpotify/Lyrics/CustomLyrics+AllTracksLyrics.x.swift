import Orion
import UIKit

private var shouldOverrideLocalTrackURI = false

// SPTPlayerTrack metadata hooks not compatible with 9.1.x
class SPTPlayerTrackHook: ClassHook<NSObject> {
    typealias Group = LyricsErrorHandlingGroup  // Not activated for 9.1.x
    static let targetName = EeveeSpotify.hookTarget == .latest
        ? "SPTPlayerTrackImplementation"
        : "SPTPlayerTrack"

    func metadata() -> [String: String] {
        var meta = orig.metadata()
        meta["has_lyrics"] = "true"
        return meta
    }
    
    func URI() -> NSURL? {
        let uri = orig.URI()
        
        guard shouldOverrideLocalTrackURI,
              let absoluteString = uri?.absoluteString,
              absoluteString.isLocalTrackIdentifier else {
            return uri
        }
        
        return NSURL(string: "spotify:track:")!
    }
}

// LyricsScrollProvider not compatible with 9.1.x
class LyricsScrollProviderHook: ClassHook<NSObject> {
    typealias Group = LyricsErrorHandlingGroup  // Not activated for 9.1.x
    static let targetName = "Lyrics_CoreImpl.LyricsScrollProvider"
    
    func isEnabledForTrack(_ track: SPTPlayerTrack) -> Bool {
        return true
    }
}

/// Notification posted when the user changes lyrics source so that the
/// NPV scroll view can invalidate its data source and force Spotify to
/// re-request the color-lyrics URL for the current track.
let EeveeLyricsSourceChangedNotification = Notification.Name("EeveeLyricsSourceChanged")

// NPVScrollViewController not compatible with 9.1.x  
class NPVScrollViewControllerHook: ClassHook<NSObject> {
    typealias Group = LyricsErrorHandlingGroup  // Not activated for 9.1.x (moved from ModernLyricsGroup)
    static var targetName = "NowPlaying_ScrollImpl.NPVScrollViewController"

    func viewWillAppear(_ animated: Bool) {
        shouldOverrideLocalTrackURI = true
        orig.viewWillAppear(animated)
        forceLyricsRefreshIfNeeded()
    }
    
    func viewWillDisappear(_ animated: Bool) {
        shouldOverrideLocalTrackURI = false
        orig.viewWillDisappear(animated)
    }
}

// V91-compatible version of NPVScrollViewController hook
class NPVScrollViewControllerV91Hook: ClassHook<NSObject> {
    typealias Group = V91LyricsGroup
    static var targetName = "NowPlaying_ScrollImpl.NPVScrollViewController"

    func viewWillAppear(_ animated: Bool) {
        shouldOverrideLocalTrackURI = true
        orig.viewWillAppear(animated)
    }
    
    func viewWillDisappear(_ animated: Bool) {
        shouldOverrideLocalTrackURI = false
        orig.viewWillDisappear(animated)
    }
}

/// When the user has changed the lyrics source, force the scroll data source to
/// remove and re-insert the LyricsScrollProvider item so Spotify re-requests
/// the color-lyrics URL for the current track.
private func forceLyricsRefreshIfNeeded() {
    guard lyricsSourceDidChange else { return }
    lyricsSourceDidChange = false
    MusixmatchLyricsRepository.shared.clearCache()

    guard let dataSource = scrollDataSource else { return }

    let lyricsProviderClassName = HookTargetNameHelper.lyricsScrollProvider

    // Find the index of the LyricsScrollProvider in activeProviders
    guard let providerIndex = dataSource.activeProviders.firstIndex(where: {
        NSStringFromClass(type(of: $0)) == lyricsProviderClassName
    }) else { return }

    let provider = dataSource.activeProviders[providerIndex]

    // Remove and re-add to force Spotify to re-initialize the provider and re-fetch
    dataSource.activeProviders.remove(at: providerIndex)

    guard let vc = npvScrollViewController else { return }
    let collectionView = vc.collectionView()
    guard let cvDataSource = collectionView.dataSource else { return }
    let diffableSource = Ivars<__UIDiffableDataSource>(cvDataSource)._impl

    let itemIdentifiers = diffableSource.itemIdentifiers()
    guard providerIndex < itemIdentifiers.count else {
        // Re-add provider and bail — can't find the item identifier
        dataSource.activeProviders.insert(provider, at: providerIndex)
        return
    }

    let identifier = itemIdentifiers[providerIndex]
    diffableSource.deleteItemsWithIdentifiers([identifier])

    // Re-add provider after a short delay so Spotify re-creates and re-fetches
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        dataSource.activeProviders.insert(provider, at: providerIndex)
        // Reload the collection view to show the new provider slot
        collectionView.reloadData()
    }
}

class NowPlayingScrollViewControllerHook: ClassHook<NSObject> {
    typealias Group = LegacyLyricsGroup
    static var targetName = EeveeSpotify.hookTarget == .v91
        ? "UIView" // Dummy target for 9.1.6
        : "NowPlaying_ScrollImpl.NowPlayingScrollViewController"
    
    func nowPlayingScrollViewModelWithDidLoadComponentsFor(
        _ track: SPTPlayerTrack,
        withDifferentProviders: Bool,
        scrollEnabledValueChanged: Bool
    ) -> NowPlayingScrollViewController {
        let controller = orig.nowPlayingScrollViewModelWithDidLoadComponentsFor(
            track,
            withDifferentProviders: withDifferentProviders,
            scrollEnabledValueChanged: scrollEnabledValueChanged
        )
        
        if !scrollEnabledValueChanged {
            controller.scrollEnabled = true
            controller.nowPlayingScrollViewModelDidChangeScrollEnabledValue()
        }
        
        return controller
    }
}
