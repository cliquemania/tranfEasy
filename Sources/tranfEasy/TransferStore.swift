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
        let existingPaths = Set(items.map { $0.url.standardizedFileURL.path })
        let uniqueURLs = urls.filter { !existingPaths.contains($0.standardizedFileURL.path) }
        guard !uniqueURLs.isEmpty else { return }
        items.append(contentsOf: uniqueURLs.map(TransferItem.init(url:)))
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
