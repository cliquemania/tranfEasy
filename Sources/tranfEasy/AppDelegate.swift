import AppKit
import TransferKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var transferViewController: TransferViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        setupPanel()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit tranfEasy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        if let image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "tranfEasy")?
            .withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = "TE"
        }
        button.toolTip = "Clique para abrir o tranfEasy"
        button.action = #selector(togglePanel)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPanel() {
        transferViewController = TransferViewController()
        transferViewController.onRequestClose = { [weak self] in
            self?.panel.orderOut(nil)
        }

        let width = Settings.width
        let height = Settings.height

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "tranfEasy"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = transferViewController
        panel.isMovableByWindowBackground = true
    }

    @objc private func togglePanel(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if panel.isVisible {
            panel.orderOut(sender)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        // Position below the status item
        if let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let panelWidth = panel.frame.width
            let panelHeight = panel.frame.height
            let x = buttonFrame.midX - panelWidth / 2
            let y = buttonFrame.minY - panelHeight - 4
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir tranfEasy", action: #selector(openPanelFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: "Limpar fila", action: #selector(clearQueue), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanelFromMenu() {
        showPanel()
    }

    @objc private func clearQueue() {
        transferViewController.clearAllItems()
    }
}
