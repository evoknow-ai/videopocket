import AppKit
import Foundation

@main
final class VideoPocketInstaller: NSObject, NSApplicationDelegate {
    private let app = NSApplication.shared
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var detailLabel: NSTextField!
    private var progressIndicator: NSProgressIndicator!
    private var actionButton: NSButton!

    static func main() {
        let delegate = VideoPocketInstaller()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Install VideoPocket"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        let title = NSTextField(labelWithString: "Install VideoPocket")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.frame = NSRect(x: 32, y: 184, width: 416, height: 32)
        content.addSubview(title)

        statusLabel = NSTextField(labelWithString: "Ready to install")
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.frame = NSRect(x: 32, y: 141, width: 416, height: 22)
        content.addSubview(statusLabel)

        detailLabel = NSTextField(wrappingLabelWithString: "The installer will close the old Helper, replace it, and start the new version.")
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.frame = NSRect(x: 32, y: 101, width: 416, height: 38)
        content.addSubview(detailLabel)

        progressIndicator = NSProgressIndicator(frame: NSRect(x: 32, y: 75, width: 416, height: 12))
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 4
        progressIndicator.doubleValue = 0
        content.addSubview(progressIndicator)

        actionButton = NSButton(title: "Install", target: self, action: #selector(beginInstallation))
        actionButton.keyEquivalent = "\r"
        actionButton.bezelStyle = .rounded
        actionButton.frame = NSRect(x: 348, y: 24, width: 100, height: 32)
        content.addSubview(actionButton)
    }

    @objc private func beginInstallation() {
        actionButton.isEnabled = false
        window.standardWindowButton(.closeButton)?.isEnabled = false
        updateProgress(0.25, status: "Preparing…", detail: "Checking the installer payload.")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.install()
                DispatchQueue.main.async {
                    self.updateProgress(4, status: "VideoPocket is ready", detail: "The Helper was installed and started successfully.")
                    self.actionButton.title = "Done"
                    self.actionButton.action = #selector(self.finish)
                    self.actionButton.isEnabled = true
                    self.window.standardWindowButton(.closeButton)?.isEnabled = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.stringValue = "Installation could not be completed"
                    self.detailLabel.stringValue = error.localizedDescription
                    self.progressIndicator.doubleValue = 0
                    self.actionButton.title = "Close"
                    self.actionButton.action = #selector(self.finish)
                    self.actionButton.isEnabled = true
                    self.window.standardWindowButton(.closeButton)?.isEnabled = true
                }
            }
        }
    }

    @objc private func finish() {
        app.terminate(nil)
    }

    private func updateProgress(_ value: Double, status: String, detail: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        progressIndicator.doubleValue = value
        statusLabel.stringValue = status
        detailLabel.stringValue = detail
    }

    private func reportProgress(_ value: Double, status: String, detail: String) {
        DispatchQueue.main.sync {
            updateProgress(value, status: status, detail: detail)
        }
    }

    private func install() throws {
        guard let payload = Bundle.main.url(
            forResource: "VideoPocket Helper",
            withExtension: "app",
            subdirectory: "Payload"
        ) else {
            throw InstallerError.missingPayload
        }

        let target = URL(fileURLWithPath: "/Applications/VideoPocket Helper.app")
        reportProgress(1, status: "Closing previous version…", detail: "Stopping any running VideoPocket Helper safely.")
        NSRunningApplication.runningApplications(withBundleIdentifier: "us.eatsleepai.videopocket.helper")
            .forEach { $0.terminate() }

        Thread.sleep(forTimeInterval: 1.0)
        NSRunningApplication.runningApplications(withBundleIdentifier: "us.eatsleepai.videopocket.helper")
            .forEach { $0.forceTerminate() }

        reportProgress(2, status: "Installing VideoPocket…", detail: "Copying the new Helper into Applications.")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: payload, to: target)

        reportProgress(3, status: "Starting VideoPocket…", detail: "Launching the new Helper and background service.")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let semaphore = DispatchSemaphore(value: 0)
        var launchError: Error?
        NSWorkspace.shared.openApplication(at: target, configuration: configuration) { _, error in
            launchError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let launchError { throw launchError }
    }
}

extension VideoPocketInstaller: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        actionButton.isEnabled
    }
}

enum InstallerError: LocalizedError {
    case missingPayload

    var errorDescription: String? {
        "The VideoPocket Helper payload is missing. Download the installer again."
    }
}
