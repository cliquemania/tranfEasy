import Foundation
import TransferKit

@MainActor
func runAllTests() {
    let fm = FileManager.default
    let service = TransferService()
    var passed = 0
    var failed = 0

    func makeTempDir() -> URL {
        let dir = fm.temporaryDirectory.appendingPathComponent("tranfEasyTests-\(UUID().uuidString)")
        try! fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func writeFile(_ content: String, at url: URL) {
        try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! content.write(to: url, atomically: true, encoding: .utf8)
    }

    func readFile(_ url: URL) -> String {
        try! String(contentsOf: url, encoding: .utf8)
    }

    func cleanup(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            print("  PASS  \(name)")
            passed += 1
        } catch {
            print("  FAIL  \(name): \(error)")
            failed += 1
        }
    }

    print("Running TransferKit tests...\n")

    test("Copy single file to empty destination") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("hello", at: src.appendingPathComponent("file.txt"))
        let items = [TransferItem(url: src.appendingPathComponent("file.txt"))]
        let summary = try service.transfer(items: items, to: dst)
        guard summary.filesCopied == 1 else { throw Err("filesCopied != 1") }
        guard readFile(dst.appendingPathComponent("file.txt")) == "hello" else { throw Err("content mismatch") }
    }

    test("Copy multiple files to empty destination") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("a", at: src.appendingPathComponent("a.txt"))
        writeFile("b", at: src.appendingPathComponent("b.txt"))
        writeFile("c", at: src.appendingPathComponent("c.txt"))
        let items = ["a.txt", "b.txt", "c.txt"].map { TransferItem(url: src.appendingPathComponent($0)) }
        let summary = try service.transfer(items: items, to: dst)
        guard summary.filesCopied == 3 else { throw Err("filesCopied != 3") }
    }

    test("Copy entire directory to empty destination") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("inside", at: src.appendingPathComponent("myFolder/nested.txt"))
        let items = [TransferItem(url: src.appendingPathComponent("myFolder"))]
        let summary = try service.transfer(items: items, to: dst)
        guard summary.directoriesCreated >= 1 else { throw Err("no directories created") }
        guard summary.filesCopied == 1 else { throw Err("filesCopied != 1") }
        guard readFile(dst.appendingPathComponent("myFolder/nested.txt")) == "inside" else { throw Err("content mismatch") }
    }

    test("On name conflict, origin file overwrites destination") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("origin", at: src.appendingPathComponent("file.txt"))
        writeFile("old-destination", at: dst.appendingPathComponent("file.txt"))
        let items = [TransferItem(url: src.appendingPathComponent("file.txt"))]
        let summary = try service.transfer(items: items, to: dst)
        guard summary.filesCopied == 1 else { throw Err("filesCopied != 1") }
        guard readFile(dst.appendingPathComponent("file.txt")) == "origin" else { throw Err("origin should win") }
    }

    test("Extra files in destination are preserved") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("new", at: src.appendingPathComponent("project/updated.txt"))
        writeFile("extra-content", at: dst.appendingPathComponent("project/extra.txt"))
        writeFile("will-be-replaced", at: dst.appendingPathComponent("project/updated.txt"))
        let items = [TransferItem(url: src.appendingPathComponent("project"))]
        _ = try service.transfer(items: items, to: dst)
        guard readFile(dst.appendingPathComponent("project/extra.txt")) == "extra-content" else { throw Err("extra file lost") }
        guard readFile(dst.appendingPathComponent("project/updated.txt")) == "new" else { throw Err("conflict not resolved by origin") }
    }

    test("Deep nested directory merge preserves extras and overwrites conflicts") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("deep-origin", at: src.appendingPathComponent("root/a/b/file.txt"))
        writeFile("deep-old", at: dst.appendingPathComponent("root/a/b/file.txt"))
        writeFile("keep-me", at: dst.appendingPathComponent("root/a/b/extra.txt"))
        let items = [TransferItem(url: src.appendingPathComponent("root"))]
        _ = try service.transfer(items: items, to: dst)
        guard readFile(dst.appendingPathComponent("root/a/b/file.txt")) == "deep-origin" else { throw Err("deep conflict not resolved") }
        guard readFile(dst.appendingPathComponent("root/a/b/extra.txt")) == "keep-me" else { throw Err("deep extra lost") }
    }

    test("Transfer to invalid destination throws error") {
        let src = makeTempDir()
        defer { cleanup(src) }
        writeFile("data", at: src.appendingPathComponent("file.txt"))
        let fake = URL(fileURLWithPath: "/tmp/tranfEasy-nonexistent-\(UUID().uuidString)")
        let items = [TransferItem(url: src.appendingPathComponent("file.txt"))]
        var didThrow = false
        do { _ = try service.transfer(items: items, to: fake) } catch is TransferError { didThrow = true }
        guard didThrow else { throw Err("should throw TransferError") }
    }

    test("Transfer with missing source throws error") {
        let dst = makeTempDir()
        defer { cleanup(dst) }
        let fake = URL(fileURLWithPath: "/tmp/tranfEasy-ghost-\(UUID().uuidString)/file.txt")
        let items = [TransferItem(url: fake)]
        var didThrow = false
        do { _ = try service.transfer(items: items, to: dst) } catch is TransferError { didThrow = true }
        guard didThrow else { throw Err("should throw TransferError") }
    }

    test("Source directory replaces file with same name at destination") {
        let src = makeTempDir(); let dst = makeTempDir()
        defer { cleanup(src); cleanup(dst) }
        writeFile("inside", at: src.appendingPathComponent("item/child.txt"))
        writeFile("i-am-a-file", at: dst.appendingPathComponent("item"))
        let items = [TransferItem(url: src.appendingPathComponent("item"))]
        let summary = try service.transfer(items: items, to: dst)
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: dst.appendingPathComponent("item").path, isDirectory: &isDir)
        guard exists && isDir.boolValue else { throw Err("item should be a directory") }
        guard readFile(dst.appendingPathComponent("item/child.txt")) == "inside" else { throw Err("content mismatch") }
        guard summary.directoriesCreated >= 1 else { throw Err("no directories created") }
    }

    test("Transfer with empty items list succeeds with zero counts") {
        let dst = makeTempDir()
        defer { cleanup(dst) }
        let summary = try service.transfer(items: [], to: dst)
        guard summary.filesCopied == 0 else { throw Err("filesCopied != 0") }
        guard summary.directoriesCreated == 0 else { throw Err("directoriesCreated != 0") }
    }

    print("\nResults: \(passed) passed, \(failed) failed out of \(passed + failed) tests")
    if failed > 0 { exit(1) }
}

struct Err: Error, CustomStringConvertible {
    let description: String
    init(_ msg: String) { description = msg }
}

MainActor.assumeIsolated {
    runAllTests()
}
