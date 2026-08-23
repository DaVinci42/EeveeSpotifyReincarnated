import Orion
import UIKit

struct WhisperModeGroup: HookGroup { }

/// Intercepts text typed into any UISearchBar. When the user types
/// "elsa4hysan" (case-insensitive), the app navigates to "Careless Whisper"
/// by George Michael.
class UISearchBarWhisperModeHook: ClassHook<UISearchBar> {
    typealias Group = WhisperModeGroup

    func setText(_ text: String?) {
        orig.setText(text)

        guard let text = text, text.lowercased() == "elsa4hysan" else { return }

        // "Careless Whisper" by George Michael (1984 original)
        if let url = URL(string: "spotify:track:6KsgCYcZKPcBRDNGhiZWRR") {
            UIApplication.shared.open(url)
        }

        // Clear the search bar after a brief pause so the user sees the redirect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setText("")
        }
    }
}

func activateWhisperMode() {
    WhisperModeGroup().activate()
    writeDebugLog("[WhisperMode] Activated")
}
