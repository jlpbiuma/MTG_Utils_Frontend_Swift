import Foundation

// MARK: - Shared app configuration

enum AppConfiguration {
    /// Base URL of the MTG Utils backend.
    ///
    /// Resolution order:
    /// 1. `UserDefaults` override `mtgBackendBaseURL` (useful for device testing).
    /// 2. `MTG_BackendBaseURL` from the Info.plist (points at this Mac's LAN IP).
    /// 3. Fallback constant.
    static func backendBaseURL() -> URL {
        if
            let override = UserDefaults.standard.string(forKey: "mtgBackendBaseURL"),
            let url = URL(string: override)
        {
            return url
        }
        if
            let fromBundle = Bundle.main.object(forInfoDictionaryKey: "MTG_BackendBaseURL") as? String,
            let url = URL(string: fromBundle)
        {
            return url
        }
        return URL(string: "http://192.168.0.112:8000")!
    }
}