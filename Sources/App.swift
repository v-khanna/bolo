import AppKit
import SwiftUI

@main
struct FreeFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appDelegate.appState)
        }
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    private var iconName: String {
        if appState.isRecording { return "record.circle" }
        if appState.isTranscribing { return "ellipsis.circle" }
        // Bolo mark: speech bubble + play (distinct from FreeFlow's waveform).
        return "play.bubble.fill"
    }

    var body: some View {
        if appState.isRecording {
            Image(systemName: "record.circle")
        } else if appState.isTranscribing {
            Image(systemName: "ellipsis.circle")
        } else if let glyph = BoloMenuBarGlyph.image {
            // Bolo's mic + sound-waves mark (bundled PNG, rendered as a template
            // so the menu bar tints it for light/dark).
            Image(nsImage: glyph).renderingMode(.template)
        } else {
            Image(systemName: iconName)
        }
    }
}

/// Loads Bolo's menu-bar glyph (Resources/MenuBarGlyph.png) sized for the menu
/// bar and flagged as a template image.
enum BoloMenuBarGlyph {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarGlyph", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        let targetHeight: CGFloat = 18
        let ratio = img.size.height > 0 ? img.size.width / img.size.height : 1
        img.size = NSSize(width: targetHeight * ratio, height: targetHeight)
        img.isTemplate = true
        return img
    }()
}

enum StampedMenuBarIcon {
    /// Bolo mark: a rounded speech bubble (with a tail) and a play triangle
    /// knocked out of it — distinct from FreeFlow's waveform. Template image so
    /// the menu bar tints it for light/dark automatically.
    static let templateImage: NSImage = {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.windingRule = .evenOdd

            // Speech bubble body (rounded rect) + a small tail at bottom-left.
            let bubble = NSRect(x: 1.5, y: 3.5, width: 15, height: 11)
            path.append(NSBezierPath(roundedRect: bubble, xRadius: 3.2, yRadius: 3.2))
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 4.5, y: 4.2))
            tail.line(to: NSPoint(x: 3.0, y: 1.0))
            tail.line(to: NSPoint(x: 7.0, y: 4.2))
            tail.close()
            path.append(tail)

            // Play triangle knocked out of the bubble (evenOdd winding).
            let play = NSBezierPath()
            play.move(to: NSPoint(x: 7.4, y: 5.6))
            play.line(to: NSPoint(x: 7.4, y: 12.4))
            play.line(to: NSPoint(x: 12.4, y: 9.0))
            play.close()
            path.append(play)

            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
