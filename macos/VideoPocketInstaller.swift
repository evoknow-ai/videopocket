import AppKit
import Foundation

@main
final class VideoPocketInstaller: NSObject, NSApplicationDelegate {
    private let app = NSApplication.shared

    static func main() {
        let delegate = VideoPocketInstaller()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        app.activate(ignoringOtherApps: true)

        let welcome = NSAlert()
        welcome.messageText = "Install VideoPocket"
        welcome.informativeText = "VideoPocket will safely close any older Helper, install the new version in Applications, and launch it for you."
        welcome.alertStyle = .informational
        welcome.addButton(withTitle: "Install")
        welcome.addButton(withTitle: "Cancel")

        guard welcome.runModal() == .alertFirstButtonReturn else {
            app.terminate(nil)
            return
        }

        do {
            try install()
            let done = NSAlert()
            done.messageText = "VideoPocket is ready"
            done.informativeText = "The Helper was installed and started. You can close this installer."
            done.alertStyle = .informational
            done.addButton(withTitle: "Done")
            done.runModal()
        } catch {
            let failed = NSAlert()
            failed.messageText = "Installation could not be completed"
            failed.informativeText = error.localizedDescription
            failed.alertStyle = .critical
            failed.addButton(withTitle: "OK")
            failed.runModal()
        }

        app.terminate(nil)
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
        NSRunningApplication.runningApplications(withBundleIdentifier: "us.eatsleepai.videopocket.helper")
            .forEach { $0.terminate() }

        Thread.sleep(forTimeInterval: 1.0)
        NSRunningApplication.runningApplications(withBundleIdentifier: "us.eatsleepai.videopocket.helper")
            .forEach { $0.forceTerminate() }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: payload, to: target)

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

enum InstallerError: LocalizedError {
    case missingPayload

    var errorDescription: String? {
        "The VideoPocket Helper payload is missing. Download the installer again."
    }
}
