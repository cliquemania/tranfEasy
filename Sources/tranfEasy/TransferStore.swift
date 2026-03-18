import Foundation
import TransferKit

@MainActor
final class TransferStore {
    private(set) var items: [TransferItem] = [] {
        didSet { onChange?() }
    }

    var destinationURL: URL? {
        didSet {
            Settings.lastDestinationPath = destinationURL?.path
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    init() {
        if let path = Settings.lastDestinationPath, !path.isEmpty {
            destinationURL = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    func add(urls: [URL]) {
        let filtered = Self.removeChildURLs(urls)
        let existingPaths = Set(items.map { $0.url.standardizedFileURL.path })
        let uniqueURLs = filtered.filter { !existingPaths.contains($0.standardizedFileURL.path) }
        guard !uniqueURLs.isEmpty else { return }

        let combined = items.map(\.url) + uniqueURLs
        let topLevel = Self.removeChildURLs(combined)
        let topLevelPaths = Set(topLevel.map { $0.standardizedFileURL.path })
        items = items.filter { topLevelPaths.contains($0.url.standardizedFileURL.path) }

        let alreadyPaths = Set(items.map { $0.url.standardizedFileURL.path })
        let toAdd = uniqueURLs.filter {
            topLevelPaths.contains($0.standardizedFileURL.path) && !alreadyPaths.contains($0.standardizedFileURL.path)
        }
        items.append(contentsOf: toAdd.map(TransferItem.init(url:)))
    }

    /// Remove URLs that are children of other URLs in the same list.
    /// e.g. if list has /a/folder and /a/folder/file.txt, only /a/folder is kept.
    private static func removeChildURLs(_ urls: [URL]) -> [URL] {
        let paths = urls.map { $0.standardizedFileURL.path }
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            let pathWithSlash = path.hasSuffix("/") ? path : path + "/"
            return !paths.contains { parent in
                parent != path && pathWithSlash.hasPrefix(parent.hasSuffix("/") ? parent : parent + "/")
            }
        }
    }

    func remove(itemID: UUID) {
        items.removeAll { $0.id == itemID }
    }

    func clearItems() {
        items.removeAll()
    }

    var hasItems: Bool {
        !items.isEmpty
    }
}
