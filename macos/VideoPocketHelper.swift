import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var installButton: NSButton!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStatus()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VideoPocket Helper"
        window.center()
        window.isReleasedWhenClosed = false

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 34, left: 42, bottom: 28, right: 42)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 88).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 88).isActive = true
        root.addArrangedSubview(icon)

        let title = NSTextField(labelWithString: "VideoPocket Helper")
        title.font = .systemFont(ofSize: 27, weight: .bold)
        root.addArrangedSubview(title)

        let subtitle = NSTextField(wrappingLabelWithString: "Private, local video downloading for the VideoPocket Chrome extension.")
        subtitle.alignment = .center
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2
        subtitle.preferredMaxLayoutWidth = 400
        root.addArrangedSubview(subtitle)

        statusLabel = NSTextField(labelWithString: "Checking helper…")
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        root.addArrangedSubview(statusLabel)

        installButton = NSButton(title: "Install Helper", target: self, action: #selector(installHelper))
        installButton.bezelStyle = .rounded
        installButton.controlSize = .large
        installButton.keyEquivalent = "\r"
        root.addArrangedSubview(installButton)

        let openDownloads = NSButton(title: "Open Downloads", target: self, action: #selector(openDownloadsFolder))
        openDownloads.bezelStyle = .inline
        root.addArrangedSubview(openDownloads)

        let credits = NSTextField(labelWithAttributedString: creditsText())
        credits.alignment = .center
        credits.isSelectable = true
        root.addArrangedSubview(credits)
    }

    private func creditsText() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "Imagined by Mohammed Kabir · Developed by his agents\n")
        let website = NSAttributedString(
            string: "eatsleepai.us",
            attributes: [.link: URL(string: "https://eatsleepai.us")!, .foregroundColor: NSColor.linkColor]
        )
        text.append(website)
        return text
    }

    private func refreshStatus() {
        guard let url = URL(string: "http://127.0.0.1:17839/health") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let ready = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                self.statusLabel.stringValue = ready ? "● Helper is installed and running" : "○ Helper is not installed"
                self.statusLabel.textColor = ready ? .systemGreen : .secondaryLabelColor
                self.installButton.title = ready ? "Reinstall Helper" : "Install Helper"
            }
        }.resume()
    }

    @objc private func installHelper() {
        guard let script = Bundle.main.url(forResource: "install_helper", withExtension: "sh") else {
            showAlert(title: "Installer missing", message: "The helper installation resource could not be found.")
            return
        }
        installButton.isEnabled = false
        statusLabel.stringValue = "Installing helper and video tools…"
        statusLabel.textColor = .secondaryLabelColor

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = environment
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output

        task.terminationHandler = { process in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: data, encoding: .utf8) ?? "No installer output."
            DispatchQueue.main.async {
                self.installButton.isEnabled = true
                if process.terminationStatus == 0 {
                    self.showAlert(title: "VideoPocket is ready", message: "The Chrome extension will pair automatically. Downloads are organized under Downloads/VideoPocket/downloads.")
                    self.refreshStatus()
                } else if process.terminationStatus == 20 {
                    self.showAlert(title: "Homebrew is required", message: "Install Homebrew from brew.sh, then reopen VideoPocket Helper.")
                    NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
                } else {
                    self.showAlert(title: "Installation failed", message: details)
                    self.statusLabel.stringValue = "Installation needs attention"
                    self.statusLabel.textColor = .systemRed
                }
            }
        }

        do { try task.run() }
        catch {
            installButton.isEnabled = true
            showAlert(title: "Could not start installer", message: error.localizedDescription)
        }
    }

    @objc private func openDownloadsFolder() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/VideoPocket/downloads")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title.contains("failed") || title.contains("missing") ? .warning : .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}
