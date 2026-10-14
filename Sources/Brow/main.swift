import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let arguments = CommandLine.arguments
    if let flag = arguments.firstIndex(of: "--render-screenshots"), flag + 1 < arguments.count {
        app.setActivationPolicy(.prohibited)
        do {
            try ScreenshotRenderer.run(outputDirectory: URL(fileURLWithPath: arguments[flag + 1]))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("Rendering failed: \(error)\n".utf8))
            exit(1)
        }
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
