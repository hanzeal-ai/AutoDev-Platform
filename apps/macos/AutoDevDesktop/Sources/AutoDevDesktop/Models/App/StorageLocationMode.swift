import Foundation

enum StorageLocationMode: String, CaseIterable, Identifiable {
    case local = "本地存储"
    case cloud = "云端存储"

    var id: String { rawValue }

    private static let key = "autodev.storageLocationMode"
    private static let pathKey = "autodev.localStoragePath"

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.key)
    }

    static func load() -> StorageLocationMode {
        UserDefaults.standard.string(forKey: key)
            .flatMap(StorageLocationMode.init(rawValue:)) ?? .local
    }

    static func saveLocalPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: pathKey)
    }

    static func loadLocalPath(fallback: String) -> String {
        UserDefaults.standard.string(forKey: pathKey) ?? fallback
    }
}
