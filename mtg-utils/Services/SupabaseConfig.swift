import Foundation

// MARK: - Supabase configuration (Phase 2)
//
// The demo runs fully offline with MockDataStore. When wiring real auth + storage in
// Phase 2, fill these from the Supabase dashboard and replace MockDataStore with a
// SupabaseSwiftClient-backed implementation of AppDataStoring.
//
// NEVER commit real keys. Load them via a .xcconfig / Info.plist or environment.

enum SupabaseConfig {
    /// e.g. "https://xyzcompany.supabase.co"
    static var supabaseURL: URL? {
        guard let raw = value(for: "SUPABASE_URL"), let url = URL(string: raw) else { return nil }
        return url
    }

    static var anonKey: String? { value(for: "SUPABASE_ANON_KEY") }

    private static func value(for key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            return nil
        }
        return value
    }
}