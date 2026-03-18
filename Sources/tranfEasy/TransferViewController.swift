import AppKit
import TransferKit

@MainActor
protocol DropZoneViewDelegate: AnyObject {
    func dropZoneView(_ view: DropZoneView, didReceive urls: [URL])
}

@MainActor
final class DropZoneView: NSView {
    weak var delegate: DropZoneViewDelegate?

    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let boundsPath = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        let fillColor = isTargeted
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : NSColor.windowBackgroundColor
        fillColor.setFill()
        boundsPath.fill()

        let strokeColor = isTargeted ? NSColor.controlAccentColor : NSColor.separatorColor
        strokeColor.setStroke()
        boundsPath.lineWidth = 2
        let dashPattern: [CGFloat] = [8, 6]
        boundsPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        boundsPath.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle
        ]

        let title = "Arraste arquivos e pastas aqui"
        let subtitle = "Depois escolha a pasta de destino e clique em Enviar"
        let titleRect = NSRect(x: 16, y: bounds.midY - 10, width: bounds.width - 32, height: 24)
        let subtitleRect = NSRect(x: 16, y: bounds.midY - 34, width: bounds.width - 32, height: 20)

        title.draw(in: titleRect, withAttributes: titleAttributes)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canReadURLs(from: sender.draggingPasteboard) else { return [] }
        isTargeted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canReadURLs(from: sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        guard let urls = readURLs(from: sender.draggingPasteboard), !urls.isEmpty else { return false }
        delegate?.dropZoneView(self, didReceive: urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    private func canReadURLs(from pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    private func readURLs(from pasteboard: NSPasteboard) -> [URL]? {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
    }
}

@MainActor
final class TransferViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, DropZoneViewDelegate {
    private let store = TransferStore()
    private let transferService = TransferService()

    var onRequestClose: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "tranfEasy")
    private let subtitleLabel = NSTextField(labelWithString: "Fila temporaria de envio")
    private let dropZoneView = DropZoneView(frame: .zero)
    private let listTitleLabel = NSTextField(labelWithString: "Itens recebidos")
    private let destinationLabel = NSTextField(labelWithString: "Destino: nao selecionado")
    private let feedbackLabel = NSTextField(labelWithString: "")
    private let chooseDestinationButton = NSButton(title: "Destino ▾", target: nil, action: nil)
    private let removeSelectedButton = NSButton(title: "Remover selecionado", target: nil, action: nil)
    private let clearButton = NSButton(title: "Limpar fila", target: nil, action: nil)
    private let sendButton = NSButton(title: "Enviar", target: nil, action: nil)
    private let tableView = NSTableView(frame: .zero)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Settings.width, height: Settings.height))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureStore()
        configureUI()
        reloadUI()
    }

    func clearAllItems() {
        store.clearItems()
        feedbackLabel.stringValue = "Fila limpa."
    }

    func dropZoneView(_ view: DropZoneView, didReceive urls: [URL]) {
        store.add(urls: urls)
        feedbackLabel.stringValue = "\(urls.count) item(ns) adicionados."
    }

    private func configureStore() {
        store.onChange = { [weak self] in
            self?.reloadUI()
        }
    }

    private func configureUI() {
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        subtitleLabel.textColor = .secondaryLabelColor
        listTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        feedbackLabel.textColor = .secondaryLabelColor
        feedbackLabel.lineBreakMode = .byTruncatingTail
        destinationLabel.lineBreakMode = .byTruncatingMiddle
        destinationLabel.maximumNumberOfLines = 2

        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.delegate = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Nome"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsEmptySelection = true

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        chooseDestinationButton.target = self
        chooseDestinationButton.action = #selector(chooseDestination)
        removeSelectedButton.target = self
        removeSelectedButton.action = #selector(removeSelected)
        clearButton.target = self
        clearButton.action = #selector(clearQueue)
        sendButton.target = self
        sendButton.action = #selector(sendItems)
        sendButton.bezelColor = .controlAccentColor

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 2
        headerStack.alignment = .leading

        let controlsRow = NSStackView(views: [chooseDestinationButton, removeSelectedButton, clearButton])
        controlsRow.orientation = .horizontal
        controlsRow.spacing = 8
        controlsRow.distribution = .fillProportionally

        let bottomRow = NSStackView(views: [sendButton])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .trailing

        let contentStack = NSStackView(views: [
            headerStack,
            dropZoneView,
            listTitleLabel,
            scrollView,
            controlsRow,
            destinationLabel,
            feedbackLabel,
            bottomRow
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            dropZoneView.heightAnchor.constraint(equalToConstant: 120),
            dropZoneView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 180),
            bottomRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])
    }

    private func reloadUI() {
        tableView.reloadData()

        let destinationText = store.destinationURL?.path ?? "nao selecionado"
        destinationLabel.stringValue = "Destino: \(destinationText)"
        removeSelectedButton.isEnabled = tableView.selectedRow >= 0 && tableView.selectedRow < store.items.count
        clearButton.isEnabled = store.hasItems
        sendButton.isEnabled = store.hasItems && store.destinationURL != nil
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TransferItemCell")
        let item = store.items[row]

        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier

        let textField: NSTextField
        if let existing = cell.textField {
            textField = existing
        } else {
            textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            cell.textField = textField
            cell.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        let kind = item.url.hasDirectoryPath ? "Pasta" : "Arquivo"
        textField.stringValue = "\(item.displayName)  •  \(kind)"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeSelectedButton.isEnabled = tableView.selectedRow >= 0 && tableView.selectedRow < store.items.count
    }

    @objc private func chooseDestination() {
        let menu = NSMenu()

        // Section: Standard locations
        let headerItem = NSMenuItem(title: "Locais", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let standardDirs: [(String, FileManager.SearchPathDirectory)] = [
            ("Mesa (Desktop)", .desktopDirectory),
            ("Documentos", .documentDirectory),
            ("Downloads", .downloadsDirectory),
        ]
        for (name, dir) in standardDirs {
            if let url = FileManager.default.urls(for: dir, in: .userDomainMask).first {
                let item = NSMenuItem(title: "  \(name)", action: #selector(selectDestinationFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                menu.addItem(item)
            }
        }

        // Home
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let homeItem = NSMenuItem(title: "  Inicio (\(homeURL.lastPathComponent))", action: #selector(selectDestinationFromMenu(_:)), keyEquivalent: "")
        homeItem.target = self
        homeItem.representedObject = homeURL
        menu.addItem(homeItem)

        // Volumes
        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for vol in volumes.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let item = NSMenuItem(title: "  \(vol.lastPathComponent)", action: #selector(selectDestinationFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = vol
                item.image = NSWorkspace.shared.icon(forFile: vol.path)
                item.image?.size = NSSize(width: 16, height: 16)
                menu.addItem(item)
            }
        }

        // Section: Tagged folders (Finder labels)
        let taggedFolders = findTaggedFolders()
        if !taggedFolders.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let tagHeader = NSMenuItem(title: "Etiquetas", action: nil, keyEquivalent: "")
            tagHeader.isEnabled = false
            menu.addItem(tagHeader)

            for (url, tags) in taggedFolders {
                let tagNames = tags.joined(separator: ", ")
                let item = NSMenuItem(title: "  \(url.lastPathComponent)  (\(tagNames))", action: #selector(selectDestinationFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.image = NSWorkspace.shared.icon(forFile: url.path)
                item.image?.size = NSSize(width: 16, height: 16)
                menu.addItem(item)
            }
        }

        // Section: Sidebar favorites
        let favorites = findSidebarFavorites()
        if !favorites.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let favHeader = NSMenuItem(title: "Favoritos", action: nil, keyEquivalent: "")
            favHeader.isEnabled = false
            menu.addItem(favHeader)

            for url in favorites {
                let item = NSMenuItem(title: "  \(url.lastPathComponent)", action: #selector(selectDestinationFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                item.image = NSWorkspace.shared.icon(forFile: url.path)
                item.image?.size = NSSize(width: 16, height: 16)
                menu.addItem(item)
            }
        }

        // Separator + browse
        menu.addItem(NSMenuItem.separator())
        let browseItem = NSMenuItem(title: "Escolher outra pasta...", action: #selector(browseDestination), keyEquivalent: "")
        browseItem.target = self
        menu.addItem(browseItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: chooseDestinationButton)
    }

    @objc private func selectDestinationFromMenu(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        store.destinationURL = url
        feedbackLabel.stringValue = "Destino: \(url.lastPathComponent)"
    }

    @objc private func browseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Usar esta pasta"
        panel.message = "Escolha a pasta de destino para o envio."
        panel.directoryURL = URL(fileURLWithPath: "/")
        panel.showsHiddenFiles = false
        panel.treatsFilePackagesAsDirectories = true

        if panel.runModal() == .OK {
            store.destinationURL = panel.url
            feedbackLabel.stringValue = "Destino selecionado."
        }
    }

    private func findTaggedFolders() -> [(URL, [String])] {
        // Use Spotlight to find folders with Finder tags
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemUserTags == '*' && kMDItemContentType == 'public.folder'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var results: [(URL, [String])] = []

        for path in paths.prefix(20) {
            let url = URL(fileURLWithPath: path)
            if let tags = try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames, !tags.isEmpty {
                results.append((url, tags))
            }
        }

        return results.sorted { $0.0.lastPathComponent < $1.0.lastPathComponent }
    }

    private func findSidebarFavorites() -> [URL] {
        // Read Finder sidebar favorites from shared file list
        let sflPath = NSHomeDirectory() + "/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl3"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sflPath)),
              let plist = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSArray.self, NSString.self, NSURL.self, NSData.self], from: data) as? NSDictionary,
              let items = plist["items"] as? [Any] else {
            return []
        }

        var urls: [URL] = []
        for item in items {
            if let dict = item as? NSDictionary,
               let bookmark = dict["Bookmark"] as? Data {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale),
                   url.hasDirectoryPath {
                    urls.append(url)
                }
            }
        }

        // Deduplicate against standard dirs already shown
        let standardPaths = Set([
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.standardizedFileURL.path,
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.standardizedFileURL.path,
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.standardizedFileURL.path,
            FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        ].compactMap { $0 })

        return urls.filter { !standardPaths.contains($0.standardizedFileURL.path) }
    }

    @objc private func removeSelected() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < store.items.count else { return }
        let item = store.items[selectedRow]
        store.remove(itemID: item.id)
        feedbackLabel.stringValue = "Item removido da fila."
    }

    @objc private func clearQueue() {
        store.clearItems()
        feedbackLabel.stringValue = "Fila limpa."
    }

    @objc private func sendItems() {
        guard let destinationURL = store.destinationURL else {
            feedbackLabel.stringValue = "Escolha uma pasta de destino antes de enviar."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Confirmar envio"
        alert.informativeText = "Enviar \(store.items.count) item(ns) para:\n\n\(destinationURL.path)\n\nConflitos por nome serao substituidos pela origem."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Enviar")
        alert.addButton(withTitle: "Cancelar")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        sendButton.isEnabled = false
        chooseDestinationButton.isEnabled = false
        removeSelectedButton.isEnabled = false
        clearButton.isEnabled = false
        feedbackLabel.stringValue = "Enviando..."

        do {
            let summary = try transferService.transfer(items: store.items, to: destinationURL)
            store.clearItems()
            feedbackLabel.stringValue = "Envio concluido."
            showResultAlert(title: "Transferencia concluida", message: "\(summary.filesCopied) arquivo(s) copiados, \(summary.directoriesCreated) pasta(s) criadas.")
            onRequestClose?()
        } catch {
            feedbackLabel.stringValue = error.localizedDescription
            showResultAlert(title: "Falha no envio", message: error.localizedDescription)
        }

        chooseDestinationButton.isEnabled = true
        removeSelectedButton.isEnabled = tableView.selectedRow >= 0 && tableView.selectedRow < store.items.count
        clearButton.isEnabled = store.hasItems
        sendButton.isEnabled = store.hasItems && store.destinationURL != nil
    }

    private func showResultAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
