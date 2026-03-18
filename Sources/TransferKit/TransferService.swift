import Foundation

public struct TransferSummary: Sendable {
    public var filesCopied = 0
    public var directoriesCreated = 0

    public init() {}
}

public enum TransferError: LocalizedError {
    case missingSource(URL)
    case invalidDestination(URL)

    public var errorDescription: String? {
        switch self {
        case .missingSource(let url):
            return "A origem nao existe mais: \(url.path)"
        case .invalidDestination(let url):
            return "A pasta de destino e invalida: \(url.path)"
        }
    }
}

public struct TransferService {
    private let fileManager = FileManager.default

    public init() {}

    public func transfer(items: [TransferItem], to destinationURL: URL) throws -> TransferSummary {
        var isDestinationDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDestinationDirectory), isDestinationDirectory.boolValue else {
            throw TransferError.invalidDestination(destinationURL)
        }

        var summary = TransferSummary()
        for item in items {
            try mergeItem(at: item.url, intoDirectory: destinationURL, summary: &summary)
        }
        return summary
    }

    private func mergeItem(at sourceURL: URL, intoDirectory destinationDirectory: URL, summary: inout TransferSummary) throws {
        var isSourceDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isSourceDirectory) else {
            throw TransferError.missingSource(sourceURL)
        }

        let targetURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if isSourceDirectory.boolValue {
            try mergeDirectory(at: sourceURL, to: targetURL, summary: &summary)
        } else {
            try copyFileReplacingDestination(at: sourceURL, to: targetURL, summary: &summary)
        }
    }

    private func mergeDirectory(at sourceURL: URL, to targetURL: URL, summary: inout TransferSummary) throws {
        var targetIsDirectory: ObjCBool = false
        let targetExists = fileManager.fileExists(atPath: targetURL.path, isDirectory: &targetIsDirectory)

        if targetExists && !targetIsDirectory.boolValue {
            try fileManager.removeItem(at: targetURL)
        }

        if !fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            summary.directoriesCreated += 1
        }

        let childURLs = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for childURL in childURLs {
            try mergeItem(at: childURL, intoDirectory: targetURL, summary: &summary)
        }
    }

    private func copyFileReplacingDestination(at sourceURL: URL, to targetURL: URL, summary: inout TransferSummary) throws {
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        if !fileManager.fileExists(atPath: targetURL.deletingLastPathComponent().path) {
            try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        try fileManager.copyItem(at: sourceURL, to: targetURL)
        summary.filesCopied += 1
    }
}
