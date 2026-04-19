import Cocoa
import ApplicationServices

// MARK: - Accessibility

enum Accessibility {
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    static func openSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Selection reader

enum SelectionReader {
    static func current(system: AXUIElement) -> String? {
        var focused: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
            let raw = focused,
            CFGetTypeID(raw) == AXUIElementGetTypeID()
        else {
            return nil
        }
        let element = raw as! AXUIElement

        var selected: AnyObject?
        guard
            AXUIElementCopyAttributeValue(
                element, kAXSelectedTextAttribute as CFString, &selected) == .success,
            let text = selected as? String,
            !text.isEmpty
        else {
            return nil
        }
        return text
    }
}

// MARK: - Copier

@MainActor
final class Copier {
    private let system: AXUIElement = AXUIElementCreateSystemWide()
    private let dragThrottle: TimeInterval = 0.1
    private var monitor: Any?
    private var lastCopied = ""
    private var lastDragRead: TimeInterval = 0

    var onCopy: ((String) -> Void)?

    private(set) var isRunning = false

    func start() {
        guard !self.isRunning else { return }
        self.isRunning = true
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .leftMouseDragged]
        self.monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    func stop() {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        self.isRunning = false
    }

    private func handle(_ event: NSEvent) {
        if event.type == .leftMouseDragged {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastDragRead >= self.dragThrottle else { return }
            self.lastDragRead = now
        }
        self.readAndCopy()
    }

    private func readAndCopy() {
        guard let text = SelectionReader.current(system: self.system),
              text != self.lastCopied else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        self.lastCopied = text
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        self.onCopy?(text)
    }
}

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let enabledKey = "autocopy.enabled"

    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var lastCopiedItem: NSMenuItem!
    private var permissionItem: NSMenuItem!

    private let copier = Copier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.buildMenu()
        self.refreshIcon()

        self.copier.onCopy = { [weak self] text in
            self?.updateLastCopied(text)
        }

        let enabled =
            UserDefaults.standard.object(forKey: self.enabledKey) as? Bool ?? true
        if enabled { self.tryEnable(promptIfNeeded: true) }
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        self.toggleItem = NSMenuItem(
            title: "Auto-Copy",
            action: #selector(self.toggleEnabled),
            keyEquivalent: "t")
        self.toggleItem.target = self
        menu.addItem(self.toggleItem)

        menu.addItem(.separator())

        self.lastCopiedItem = NSMenuItem(title: "Last copied: —", action: nil, keyEquivalent: "")
        self.lastCopiedItem.isEnabled = false
        menu.addItem(self.lastCopiedItem)

        menu.addItem(.separator())

        self.permissionItem = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(self.openAccessibilitySettings),
            keyEquivalent: "")
        self.permissionItem.target = self
        menu.addItem(self.permissionItem)

        menu.addItem(
            NSMenuItem(
                title: "Quit Auto-Copy", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        self.toggleItem.title = self.copier.isRunning ? "Pause Auto-Copy" : "Start Auto-Copy"
        self.toggleItem.state = self.copier.isRunning ? .on : .off
        self.permissionItem.isHidden = Accessibility.isTrusted(prompt: false)
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        if self.copier.isRunning {
            self.copier.stop()
            UserDefaults.standard.set(false, forKey: self.enabledKey)
        } else {
            self.tryEnable(promptIfNeeded: true)
            UserDefaults.standard.set(self.copier.isRunning, forKey: self.enabledKey)
        }
        self.refreshIcon()
    }

    @objc private func openAccessibilitySettings() {
        Accessibility.openSettings()
    }

    // MARK: Helpers

    private func tryEnable(promptIfNeeded: Bool) {
        guard Accessibility.isTrusted(prompt: promptIfNeeded) else { return }
        self.copier.start()
        self.refreshIcon()
    }

    private func refreshIcon() {
        let name = self.copier.isRunning ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let image = NSImage(
            systemSymbolName: name, accessibilityDescription: "Auto-Copy")
        image?.isTemplate = true
        self.statusItem.button?.image = image
    }

    private func updateLastCopied(_ text: String) {
        let single = text.replacingOccurrences(of: "\n", with: " ")
        let preview = single.count > 40 ? single.prefix(40) + "…" : Substring(single)
        self.lastCopiedItem.title = "Last copied: \(preview)"
    }
}

// MARK: - Entry point

@main
enum AutoCopy {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
