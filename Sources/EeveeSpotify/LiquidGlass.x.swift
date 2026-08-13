import Orion
import Foundation
import UIKit

// Spotify ships with `UIDesignRequiresCompatibility = true` in its Info.plist. This is
// Apple's documented iOS 26 opt-out flag: when present and true, UIKit/SwiftUI keep
// rendering standard chrome (nav bars, tab bars, toolbars, alerts, search bars, etc.)
// in the pre-iOS 26 style instead of the new Liquid Glass material, regardless of the
// device's actual OS version. Spotify also ships its own hand-rolled glass components
// (Reprise_LiquidGlassKit — ChipGlassView, GradientView, SearchBarView, etc.) that are
// gated separately and rolled out gradually; those are internal Swift types with no
// exported symbols to hook, so they're out of reach here.
//
// This hook only flips the documented, Apple-level switch: NSBundle is intercepted so
// that when Spotify's own UIKit init path asks the main bundle for
// "UIDesignRequiresCompatibility", it gets `false` back, letting the OS apply native
// Liquid Glass to Spotify's standard UIKit/SwiftUI surfaces. Has no effect below iOS 26.

struct LiquidGlassGroup: HookGroup { }

class NSBundleLiquidGlassHook: ClassHook<NSObject> {
    typealias Group = LiquidGlassGroup
    static let targetName = "NSBundle"

    func objectForInfoDictionaryKey(_ key: NSString) -> Any? {
        if key == "UIDesignRequiresCompatibility",
           let bundle = target as? Bundle,
           bundle == Bundle.main {
            return NSNumber(value: false)
        }

        return orig.objectForInfoDictionaryKey(key)
    }
}

func activateLiquidGlass() {
    guard UserDefaults.forceLiquidGlass else { return }

    if #unavailable(iOS 26.0) {
        writeDebugLog("[LiquidGlass] Skipped: requires iOS 26+")
        return
    }

    LiquidGlassGroup().activate()
    writeDebugLog("[LiquidGlass] Activated - forcing UIDesignRequiresCompatibility=false")
}
