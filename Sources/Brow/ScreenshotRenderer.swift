import AppKit
import BrowCore
import SwiftUI

/// `Brow --render-screenshots <dir>` draws the README pictures from the real views
/// with demo data. Storage goes to a temporary folder, so no real history, files
/// or notes ever end up in an image.
@MainActor
enum ScreenshotRenderer {
    static func run(outputDirectory: URL) throws {
        let dataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("brow-screenshots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dataDirectory) }
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let model = AppModel(directory: dataDirectory)
        try fillDemoData(model, filesIn: dataDirectory.appendingPathComponent("files"))
        let screen = NotchScreenInfo(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                     safeAreaTop: 32, leftAreaWidth: 663.5, rightAreaWidth: 663.5)
        let geometry = NotchGeometry(screen: screen)!
        model.panel = PanelStateMachine(geometry: geometry)

        try render(model, to: outputDirectory.appendingPathComponent("collapsed.png"))
        model.mouseMoved(to: CGPoint(x: geometry.notchRect.midX, y: geometry.notchRect.midY))
        for (tab, name) in [(PanelTab.shelf, "shelf"), (.clipboard, "clipboard"),
                            // Notes last: leaving the notes tab re-checks the real cursor, which closes the panel here.
            (.screenshots, "screenshots"), (.links, "links"), (.notes, "notes")] {
            model.select(tab)
            try render(model, to: outputDirectory.appendingPathComponent("\(name).png"))
        }
    }

    private static func fillDemoData(_ model: AppModel, filesIn directory: URL) throws {
        model.media = .playing(NowPlaying(
            title: "Aurora Drive", artist: "Northern Lights", album: "Demo",
            artwork: artwork(), duration: 243, elapsed: 87, timestamp: .now,
            isPlaying: true, bundleId: nil))

        for text in [
            "brew install gh",
            "https://github.com/freedrobili/brow",
            "Встреча в 15:00, переговорка «Нева»",
            "Привет! Скинь, пожалуйста, макет к вечеру",
        ] {
            model.clipboardChanged(text, types: [])
        }

        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Проект"),
                                                withIntermediateDirectories: true)
        let files = ["Отчёт.pdf", "Скриншот.png", "Презентация.key", "Таблица.xlsx"]
        for name in files {
            FileManager.default.createFile(atPath: directory.appendingPathComponent(name).path, contents: Data())
        }
        model.addToShelf((files + ["Проект"]).map { directory.appendingPathComponent($0) })

        for (top, bottom) in [((0.95, 0.55, 0.35), (0.85, 0.25, 0.45)),
                              ((0.3, 0.7, 0.95), (0.2, 0.3, 0.8)),
                              ((0.45, 0.85, 0.6), (0.1, 0.5, 0.45)),
                              ((0.98, 0.85, 0.4), (0.95, 0.5, 0.3))] {
            if let png = demoScreenshot(top: top, bottom: bottom) { model.screenshotTaken(png) }
        }

        var links = LinkStore()
        for (address, title) in [("https://example.com/podcast", "Подкаст про дизайн"),
                                 ("https://example.com/recipes/42", "Рецепт сырников"),
                                 ("https://books.example.com/book/1", "Мастер и Маргарита — читать онлайн")] {
            let id = links.add(URL(string: address)!)
            links.setPageInfo(id: id, title: title, icon: nil)
        }
        model.links = links

        model.noteText = "Купить: молоко, кофе\nПозвонить в сервис до пятницы\nИдея: тёмная тема для полки"
    }

    private static func render(_ model: AppModel, to url: URL) throws {
        let view = NSHostingView(rootView: ScreenshotScene(model: model))
        view.frame = NSRect(origin: .zero, size: ScreenshotScene.size)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        // Let SwiftUI finish layout and the expand animation.
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        view.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil) }

        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
        print("wrote \(url.path)")
    }

    /// A fake window on a gradient, standing in for a real screenshot.
    private static func demoScreenshot(top: (Double, Double, Double), bottom: (Double, Double, Double)) -> Data? {
        let image = NSImage(size: NSSize(width: 800, height: 520), flipped: false) { rect in
            NSGradient(starting: NSColor(calibratedRed: top.0, green: top.1, blue: top.2, alpha: 1),
                       ending: NSColor(calibratedRed: bottom.0, green: bottom.1, blue: bottom.2, alpha: 1))!
                .draw(in: rect, angle: -60)
            let window = rect.insetBy(dx: 120, dy: 90)
            NSColor.white.withAlphaComponent(0.92).setFill()
            NSBezierPath(roundedRect: window, xRadius: 18, yRadius: 18).fill()
            NSColor.black.withAlphaComponent(0.12).setFill()
            for row in 0..<4 {
                let y = window.maxY - 70 - CGFloat(row) * 60
                NSBezierPath(roundedRect: NSRect(x: window.minX + 40, y: y, width: window.width - 80 - CGFloat(row) * 60, height: 26),
                             xRadius: 13, yRadius: 13).fill()
            }
            return true
        }
        guard let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    /// A plain gradient square standing in for album art.
    private static func artwork() -> Data? {
        let image = NSImage(size: NSSize(width: 300, height: 300), flipped: false) { rect in
            NSGradient(starting: NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.4, alpha: 1),
                       ending: NSColor(calibratedRed: 0.35, green: 0.3, blue: 0.85, alpha: 1))!
                .draw(in: rect, angle: -45)
            return true
        }
        guard let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }
}

/// A slice of desktop: wallpaper, menu bar, and the panel over the notch.
private struct ScreenshotScene: View {
    static let size = CGSize(width: 760, height: 228)
    let model: AppModel

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.13, green: 0.18, blue: 0.45),
                                    Color(red: 0.5, green: 0.33, blue: 0.72),
                                    Color(red: 0.93, green: 0.58, blue: 0.55)],
                           startPoint: .top, endPoint: .bottomTrailing)
            menuBar
            NotchRootView(model: model)
                .frame(width: NotchGeometry.expandedSize.width, height: NotchGeometry.expandedSize.height)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var menuBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo")
            Text("Finder").fontWeight(.bold)
            Text("Файл")
            Text("Правка")
            Text("Вид")
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Ср 14 окт. 16:42")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(.black.opacity(0.25))
    }
}
