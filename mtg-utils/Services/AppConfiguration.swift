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

    /// Converts worker URLs that use the host's loopback address into URLs
    /// reachable from a physical iOS device on the same LAN.
    static func reachableImageURL(_ url: URL?) -> URL? {
        guard let url else { return nil }
        guard
            ["localhost", "127.0.0.1", "::1"].contains(url.host ?? ""),
            url.port == 8080,
            let backendHost = backendBaseURL().host
        else {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = backendHost
        return components?.url
    }

    static func imageURL(from value: String?) -> URL? {
        guard let value, let url = URL(string: value) else { return nil }
        return reachableImageURL(url)
    }
}
