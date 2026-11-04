import AppKit
import SwiftUI

/// Tracks the main SwiftUI window so global keyboard handling can distinguish
/// it from Settings and the menu-bar panel without overwriting SwiftUI's own
/// window identifier.
@MainActor
enum MainWindowRegistry {
    static weak var window: NSWindow?
}

struct MainWindowMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MainWindowMarkerView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            MainWindowRegistry.window = window
        }
    }
}

private final class MainWindowMarkerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            MainWindowRegistry.window = window
        }
    }
}
