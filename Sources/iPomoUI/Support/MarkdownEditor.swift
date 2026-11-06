import AppKit
import SwiftUI

// MARK: - Auto-completing Markdown text editor

/// An `NSTextView`-backed editor used for Markdown notes. It keeps the warm
/// editorial styling of `PaperTextEditor` while adding the small editing
/// affordances a Markdown note wants: bracket/quote auto-pairing, pair
/// deletion, list continuation, and ⌘K / ⌘B / ⌘I / ⌘` shortcuts.
struct PaperTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 96

    var body: some View {
        MarkdownNSTextView(text: $text, minHeight: minHeight)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .fill(DesignTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                    .strokeBorder(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous))
    }
}

struct MarkdownNSTextView: NSViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = PaperNSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = PaperNSTextView.inkColor
        textView.backgroundColor = .clear
        textView.insertionPointColor = PaperNSTextView.inkColor
        textView.selectedTextAttributes = [
            .backgroundColor: PaperNSTextView.selectionColor
        ]

        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        textView.string = text
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.coordinator = context.coordinator

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isEditing {
            let selected = textView.selectedRange()
            textView.string = text
            let clamped = min(selected.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: clamped, length: 0))
        }
        textView.textColor = PaperNSTextView.inkColor
        textView.backgroundColor = .clear
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownNSTextView
        weak var textView: NSTextView?
        var isEditing = false

        init(_ parent: MarkdownNSTextView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = textView.string
        }

        private let pairs: [Character: Character] = [
            "(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"
        ]

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString else { return true }

            // Backspace over an empty pair deletes both characters.
            if replacement.isEmpty && affectedRange.length == 1 {
                let ns = textView.string as NSString
                if affectedRange.location < ns.length {
                    let deleted = ns.substring(with: affectedRange)
                    if let pair = pairs[Character(deleted)] {
                        let nextLocation = affectedRange.location + 1
                        if nextLocation < ns.length {
                            let next = ns.substring(with: NSRange(location: nextLocation, length: 1))
                            if next == String(pair) {
                                let both = NSRange(location: affectedRange.location, length: 2)
                                textView.replaceCharacters(in: both, with: "")
                                textView.setSelectedRange(NSRange(location: affectedRange.location, length: 0))
                                return false
                            }
                        }
                    }
                }
            }

            // Auto-pair opening brackets/quotes.
            if replacement.count == 1, let ch = replacement.first, let pair = pairs[ch] {
                let ns = textView.string as NSString
                // Only auto-pair quotes in contexts where it's likely intended.
                if ch == "\"" || ch == "'" {
                    let prev: String
                    if affectedRange.location > 0 {
                        prev = ns.substring(with: NSRange(location: affectedRange.location - 1, length: 1))
                    } else {
                        prev = ""
                    }
                    let nextChar: String
                    if affectedRange.location < ns.length {
                        nextChar = ns.substring(with: NSRange(location: affectedRange.location, length: 1))
                    } else {
                        nextChar = ""
                    }
                    let prevOK = prev.isEmpty || " \t\n([{".contains(prev)
                    let nextOK = nextChar.isEmpty || " \t\n,.;:!?)]}".contains(nextChar)
                    if !(prevOK && nextOK) {
                        return true
                    }
                }
                if affectedRange.length > 0 {
                    let selected = ns.substring(with: affectedRange)
                    let wrapped = String(ch) + selected + String(pair)
                    textView.insertText(wrapped, replacementRange: affectedRange)
                    let inner = NSRange(location: affectedRange.location + 1, length: selected.count)
                    textView.setSelectedRange(inner)
                    return false
                }
                // Skip over a matching closing bracket that is already present.
                if ch == ")" || ch == "]" || ch == "}" || ch == "\"" || ch == "'" {
                    if affectedRange.location < ns.length {
                        let next = ns.substring(with: NSRange(location: affectedRange.location, length: 1))
                        if next == replacement {
                            textView.setSelectedRange(NSRange(location: affectedRange.location + 1, length: 0))
                            return false
                        }
                    }
                }
                // Insert the pair and leave the caret in the middle.
                if ch == "(" || ch == "[" || ch == "{" || ch == "\"" || ch == "'" {
                    textView.insertText(String(ch) + String(pair), replacementRange: affectedRange)
                    textView.setSelectedRange(NSRange(location: affectedRange.location + 1, length: 0))
                    return false
                }
            }

            // Auto-continue lists on Enter.
            if replacement == "\n" {
                if let continuation = listContinuation(in: textView, at: affectedRange) {
                    textView.insertText("\n" + continuation, replacementRange: affectedRange)
                    return false
                }
            }

            return true
        }

        private func listContinuation(in textView: NSTextView, at range: NSRange) -> String? {
            let ns = textView.string as NSString
            let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let line = ns.substring(with: lineRange)
            // Preserve leading indentation.
            let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
            let trimmed = line.dropFirst(leading.count)
            // Match a list marker.
            let markers = ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ "]
            for marker in markers {
                if trimmed.hasPrefix(marker) {
                    let nextMarker: String
                    if marker.hasPrefix("- [") {
                        nextMarker = "- [ ] "
                    } else {
                        nextMarker = marker
                    }
                    return String(leading) + nextMarker
                }
            }
            // Ordered lists: "1. "
            if let dotIndex = trimmed.firstIndex(of: "."),
               trimmed[trimmed.startIndex..<dotIndex].allSatisfy({ $0.isNumber }),
               trimmed.index(after: dotIndex) < trimmed.endIndex,
               trimmed[trimmed.index(after: dotIndex)] == " " {
                let numberString = String(trimmed[trimmed.startIndex..<dotIndex])
                if let number = Int(numberString) {
                    let indent = String(leading)
                    return indent + "\(number + 1). "
                }
            }
            // If the line is just a marker with no content, stop the list (remove marker).
            let stripped = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            if markers.contains(where: { stripped == String($0).trimmingCharacters(in: .whitespaces) }) {
                // Remove the marker line by replacing with empty newline.
                return nil
            }
            return nil
        }
    }
}

// MARK: - NSTextView subclass with keyboard shortcuts

final class PaperNSTextView: NSTextView {
    weak var coordinator: MarkdownNSTextView.Coordinator?

    static let inkColor: NSColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(hex: 0xF1E9DD) : NSColor(hex: 0x211C17)
    }

    static let selectionColor: NSColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(hex: 0x3B342C) : NSColor(hex: 0xDCD2C3)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        let key = (event.charactersIgnoringModifiers ?? "").lowercased()
        switch key {
        case "k":
            insertMarkdownLink()
            return true
        case "b":
            wrapSelection(prefix: "**", suffix: "**")
            return true
        case "i":
            wrapSelection(prefix: "*", suffix: "*")
            return true
        case "`":
            if event.modifierFlags.contains(.shift) {
                wrapSelection(prefix: "```\n", suffix: "\n```")
            } else {
                wrapSelection(prefix: "`", suffix: "`")
            }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    private func insertMarkdownLink() {
        let range = selectedRange()
        let ns = string as NSString
        let selected = range.length > 0 ? ns.substring(with: range) : ""
        let linkText = selected.isEmpty ? "text" : selected
        // Prefer a URL sitting on the pasteboard as the link target.
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")) ? trimmed : "url"
        let template = "[\(linkText)](\(url))"
        insertText(template, replacementRange: range)
        if url == "url" {
            // Select "url" so it can be typed over.
            let prefixLength = 1 + linkText.count + 1 + 1 // [ text ] (
            let urlRange = NSRange(location: range.location + prefixLength, length: 3)
            setSelectedRange(urlRange)
        } else {
            // Leave the caret after the closing parenthesis.
            let caret = range.location + template.count
            setSelectedRange(NSRange(location: caret, length: 0))
        }
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        let ns = string as NSString
        let selected = range.length > 0 ? ns.substring(with: range) : ""
        let inner = selected.isEmpty ? "text" : selected
        let wrapped = prefix + inner + suffix
        insertText(wrapped, replacementRange: range)
        if selected.isEmpty {
            // Place caret inside.
            let caret = range.location + prefix.count
            setSelectedRange(NSRange(location: caret, length: inner.count))
        } else {
            // Keep original selection inside markers.
            let newRange = NSRange(location: range.location + prefix.count, length: selected.count)
            setSelectedRange(newRange)
        }
    }
}
