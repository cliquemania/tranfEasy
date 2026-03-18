import Foundation

public struct TransferItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var displayName: String {
        url.lastPathComponent
    }
}
