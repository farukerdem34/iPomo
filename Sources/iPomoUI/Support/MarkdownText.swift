import Foundation
import SwiftUI

/// A parsed Markdown note. Parsing uses Foundation's Markdown reader so inline
/// emphasis, code spans, links, and block structure follow the same rules as
/// the rest of Apple's Markdown support.
struct MarkdownDocument {
    enum ListMarker: Equatable {
        case bullet
        case ordered(Int)
        case task(checked: Bool)
    }

    enum BlockKind {
        case paragraph
        case heading(level: Int)
        case listItem(depth: Int, marker: ListMarker)
        case codeBlock(language: String?)
        case thematicBreak
        case table(Table)
    }

    struct Block {
        let id: Int
        let kind: BlockKind
        let content: AttributedString
        /// How deeply nested inside block quotes this block sits.
        let quoteDepth: Int
        /// Identity of the outermost block quote, used to draw one quote rule.
        let quoteID: Int?
    }

    struct Table {
        enum ColumnAlignment: Equatable {
            case leading
            case center
            case trailing
        }

        struct Cell {
            let column: Int
            let content: AttributedString
        }

        struct Row: Identifiable {
            let id: Int
            let cells: [Cell]
        }

        let columnCount: Int
        let alignments: [ColumnAlignment]
        let header: [Cell]
        let rows: [Row]
    }

    let blocks: [Block]

    var isEmpty: Bool { blocks.isEmpty }

    static func parse(_ source: String) -> MarkdownDocument {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MarkdownDocument(blocks: [])
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        guard let attributed = try? AttributedString(markdown: source, options: options) else {
            return MarkdownDocument(blocks: [
                Block(id: 0, kind: .paragraph, content: AttributedString(source), quoteDepth: 0, quoteID: nil)
            ])
        }

        return MarkdownDocument(blocks: extractBlocks(from: attributed))
    }

    static func cached(_ source: String) -> MarkdownDocument {
        let key = source as NSString
        if let entry = cache.object(forKey: key) {
            return entry.document
        }
        let document = parse(source)
        cache.setObject(MarkdownCacheEntry(document), forKey: key)
        return document
    }

    // MARK: - Parsing

    private static let cache: NSCache<NSString, MarkdownCacheEntry> = {
        let cache = NSCache<NSString, MarkdownCacheEntry>()
        // Bound the cache so parsed notes (with their AttributedString payloads)
        // cannot grow unbounded in memory.
        cache.countLimit = 8
        return cache
    }()

    private static func extractBlocks(from attributed: AttributedString) -> [Block] {
        var blocks: [Block] = []
        var currentKey: [Int]?
        var currentComponents: [PresentationIntent.IntentType] = []
        var currentContent = AttributedString()
        var table: TableAccumulator?

        func append(_ kind: BlockKind, content: AttributedString, components: [PresentationIntent.IntentType]) {
            let quotes = components.filter {
                if case .blockQuote = $0.kind { return true }
                return false
            }
            let quoteDepth = quotes.count
            let quoteID = quotes.last?.identity

            var content = content
            var kind = kind
            if case .codeBlock = kind {
                var raw = String(content.characters)
                while raw.hasSuffix("\n") {
                    raw.removeLast()
                }
                content = AttributedString(raw)
            }
            if case .listItem(let depth, .bullet) = kind, let task = taskMarker(in: content) {
                content = task.content
                kind = .listItem(depth: depth, marker: .task(checked: task.checked))
            }

            if case .paragraph = kind, content.characters.isEmpty {
                return
            }

            blocks.append(Block(
                id: blocks.count,
                kind: kind,
                content: content,
                quoteDepth: quoteDepth,
                quoteID: quoteID
            ))
        }

        func flushCurrent() {
            guard currentKey != nil else { return }
            let content = currentContent
            let components = currentComponents
            currentKey = nil
            currentComponents = []
            currentContent = AttributedString()

            guard let kind = blockKind(from: components) else { return }
            append(kind, content: content, components: components)
        }

        func flushTable() {
            guard let accumulator = table else { return }
            table = nil
            let table = accumulator.build()
            blocks.append(Block(
                id: blocks.count,
                kind: .table(table),
                content: AttributedString(),
                quoteDepth: accumulator.quoteDepth,
                quoteID: accumulator.quoteID
            ))
        }

        for run in attributed.runs {
            let slice = AttributedString(attributed[run.range])
            let components = run.presentationIntent?.components ?? []

            if let tableComponent = components.first(where: { component in
                if case .table = component.kind { return true }
                return false
            }) {
                flushCurrent()

                if table?.identity != tableComponent.identity {
                    flushTable()
                    guard case .table(let columns) = tableComponent.kind else { continue }
                    let quotes = components.filter {
                        if case .blockQuote = $0.kind { return true }
                        return false
                    }
                    table = TableAccumulator(
                        identity: tableComponent.identity,
                        columnCount: columns.count,
                        alignments: columns.map { column in
                            switch column.alignment {
                            case .left: return .leading
                            case .center: return .center
                            case .right: return .trailing
                            @unknown default: return .leading
                            }
                        },
                        quoteDepth: quotes.count,
                        quoteID: quotes.last?.identity
                    )
                }

                table?.append(slice, components: components)
                continue
            }

            flushTable()

            let key = components.map(\.identity)
            if currentKey != key {
                flushCurrent()
                currentKey = key
                currentComponents = components
            }
            currentContent = currentContent + slice
        }

        flushTable()
        flushCurrent()
        return blocks
    }

    private static func blockKind(from components: [PresentationIntent.IntentType]) -> BlockKind? {
        for component in components {
            switch component.kind {
            case .codeBlock(let language):
                return .codeBlock(language: language)
            case .header(let level):
                return .heading(level: level)
            case .thematicBreak:
                return .thematicBreak
            case .listItem(let ordinal):
                let listItems = components.filter {
                    if case .listItem = $0.kind { return true }
                    return false
                }
                let depth = listItems.count
                guard let index = components.firstIndex(where: { candidate in
                    if case .listItem = candidate.kind { return true }
                    return false
                }), index + 1 < components.count else {
                    return .listItem(depth: depth, marker: .bullet)
                }
                if case .orderedList = components[index + 1].kind {
                    return .listItem(depth: depth, marker: .ordered(ordinal))
                }
                return .listItem(depth: depth, marker: .bullet)
            case .table:
                return nil
            default:
                continue
            }
        }
        return .paragraph
    }

    private static func taskMarker(in content: AttributedString) -> (content: AttributedString, checked: Bool)? {
        let text = String(content.characters)
        for (prefix, checked) in [("[ ] ", false), ("[x] ", true), ("[X] ", true)] where text.hasPrefix(prefix) {
            let end = content.index(content.startIndex, offsetByCharacters: prefix.count)
            var stripped = content
            stripped.removeSubrange(stripped.startIndex..<end)
            return (stripped, checked)
        }
        return nil
    }

    private final class MarkdownCacheEntry {
        let document: MarkdownDocument

        init(_ document: MarkdownDocument) {
            self.document = document
        }
    }

    // MARK: - Tables

    private struct TableAccumulator {
        struct RowAccumulator {
            let identity: Int
            var cells: [Int: AttributedString]
        }

        let identity: Int
        let columnCount: Int
        let alignments: [Table.ColumnAlignment]
        let quoteDepth: Int
        let quoteID: Int?
        var header: RowAccumulator?
        var rows: [RowAccumulator] = []

        mutating func append(_ slice: AttributedString, components: [PresentationIntent.IntentType]) {
            guard let cellComponent = components.first(where: { component in
                if case .tableCell = component.kind { return true }
                return false
            }), case .tableCell(let column) = cellComponent.kind else {
                return
            }

            guard let rowComponent = components.first(where: { component in
                switch component.kind {
                case .tableHeaderRow, .tableRow: return true
                default: return false
                }
            }) else {
                return
            }

            let isHeader: Bool
            if case .tableHeaderRow = rowComponent.kind {
                isHeader = true
            } else {
                isHeader = false
            }

            if isHeader {
                var accumulator = header ?? RowAccumulator(identity: rowComponent.identity, cells: [:])
                accumulator.cells[column] = (accumulator.cells[column] ?? AttributedString()) + slice
                header = accumulator
            } else if let index = rows.firstIndex(where: { $0.identity == rowComponent.identity }) {
                rows[index].cells[column] = (rows[index].cells[column] ?? AttributedString()) + slice
            } else {
                rows.append(RowAccumulator(identity: rowComponent.identity, cells: [column: slice]))
            }
        }

        func build() -> Table {
            func cells(_ cells: [Int: AttributedString]) -> [Table.Cell] {
                (0..<columnCount).map { column in
                    Table.Cell(column: column, content: cells[column] ?? AttributedString())
                }
            }

            let headerCells = header.map { cells($0.cells) }
                ?? (0..<columnCount).map { Table.Cell(column: $0, content: AttributedString()) }
            let builtRows = rows.map { Table.Row(id: $0.identity, cells: cells($0.cells)) }

            return Table(
                columnCount: columnCount,
                alignments: alignments,
                header: headerCells,
                rows: builtRows
            )
        }
    }
}

/// Renders a Markdown note with the Warm Editorial design language.
struct MarkdownText: View {
    var text: String
    var color: Color = DesignTokens.inkSecondary
    var fontSize: CGFloat = 13

    @Environment(\.editorialAccent) private var accent

    private var document: MarkdownDocument {
        MarkdownDocument.cached(text)
    }

    var body: some View {
        let items = MarkdownItem.group(document.blocks)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                view(for: item)
                    .padding(.bottom, spacing(after: index, in: items))
            }
        }
        .tint(accent)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for item: MarkdownItem) -> some View {
        switch item {
        case .block(let block):
            blockView(block)
        case .quote(_, let blocks):
            HStack(alignment: .top, spacing: DesignTokens.s3) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(accent.opacity(0.4))
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: DesignTokens.s2) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownDocument.Block) -> some View {
        switch block.kind {
        case .paragraph:
            textView(block.content, font: Typography.body(fontSize))
        case .heading(let level):
            textView(block.content, font: headingFont(level), color: DesignTokens.ink)
        case .listItem(let depth, let marker):
            listItem(block.content, depth: depth, marker: marker)
        case .codeBlock:
            codeBlock(block.content)
        case .thematicBreak:
            Hairline()
                .padding(.vertical, DesignTokens.s1)
        case .table(let table):
            MarkdownTableView(table: table, fontSize: fontSize, color: color)
        }
    }

    private func textView(
        _ content: AttributedString,
        font: Font,
        color: Color? = nil
    ) -> some View {
        Text(styledInline(content))
            .font(font)
            .foregroundStyle(color ?? self.color)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listItem(
        _ content: AttributedString,
        depth: Int,
        marker: MarkdownDocument.ListMarker
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.s2) {
            listMarker(marker)
            Text(styledInline(content))
                .font(Typography.body(fontSize))
                .foregroundStyle(color)
                .strikethrough(isChecked(marker))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(max(depth - 1, 0)) * 16)
    }

    @ViewBuilder
    private func listMarker(_ marker: MarkdownDocument.ListMarker) -> some View {
        switch marker {
        case .bullet:
            Text("•")
                .font(Typography.bodyMedium(fontSize))
                .foregroundStyle(DesignTokens.inkTertiary)
                .frame(minWidth: 14, alignment: .trailing)
        case .ordered(let number):
            Text("\(number).")
                .font(Typography.body(fontSize))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.inkTertiary)
                .frame(minWidth: 14, alignment: .trailing)
        case .task(let checked):
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: max(fontSize - 1, 10), weight: .regular))
                .foregroundStyle(checked ? accent : DesignTokens.inkTertiary)
                .frame(minWidth: 14, alignment: .trailing)
        }
    }

    private func codeBlock(_ content: AttributedString) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(String(content.characters))
                .font(.system(size: max(fontSize - 1, 10), design: .monospaced))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                .fill(DesignTokens.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.r2, style: .continuous)
                .strokeBorder(DesignTokens.hairline, lineWidth: 1)
        )
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return Typography.section(fontSize + 7)
        case 2: return Typography.section(fontSize + 4)
        case 3: return Typography.heading(fontSize + 2)
        case 4: return Typography.heading(fontSize + 1)
        case 5: return Typography.bodyMedium(fontSize)
        default: return Typography.bodyMedium(max(fontSize - 1, 10))
        }
    }

    private func isChecked(_ marker: MarkdownDocument.ListMarker) -> Bool {
        if case .task(let checked) = marker {
            return checked
        }
        return false
    }

    private func styledInline(_ content: AttributedString) -> AttributedString {
        var result = content
        let codeRanges = result.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard run.inlinePresentationIntent?.contains(.code) == true else { return nil }
            return run.range
        }
        for range in codeRanges {
            result[range].font = .system(size: max(fontSize - 1, 10), design: .monospaced)
            result[range].foregroundColor = DesignTokens.ink
        }
        return result
    }

    private func spacing(after index: Int, in items: [MarkdownItem]) -> CGFloat {
        guard index < items.count - 1 else { return 0 }
        if case .block(let current) = items[index], case .heading = current.kind {
            return DesignTokens.s2
        }
        if case .block(let current) = items[index],
           case .listItem = current.kind,
           case .block(let next) = items[index + 1],
           case .listItem = next.kind {
            return DesignTokens.s1
        }
        return DesignTokens.s3
    }
}

private enum MarkdownItem {
    case block(MarkdownDocument.Block)
    case quote(id: Int, blocks: [MarkdownDocument.Block])

    static func group(_ blocks: [MarkdownDocument.Block]) -> [MarkdownItem] {
        var items: [MarkdownItem] = []
        var index = 0

        while index < blocks.count {
            let block = blocks[index]
            if let quoteID = block.quoteID {
                var grouped = [block]
                var next = index + 1
                while next < blocks.count, blocks[next].quoteID == quoteID {
                    grouped.append(blocks[next])
                    next += 1
                }
                items.append(.quote(id: quoteID, blocks: grouped))
                index = next
            } else {
                items.append(.block(block))
                index += 1
            }
        }

        return items
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownDocument.Table
    let fontSize: CGFloat
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: DesignTokens.s3, verticalSpacing: DesignTokens.s1) {
                GridRow {
                    ForEach(table.header, id: \.column) { cell in
                        headerCell(cell)
                            .gridColumnAlignment(alignment(for: cell.column))
                    }
                }

                Rectangle()
                    .fill(DesignTokens.hairline)
                    .frame(height: 1)
                    .gridCellColumns(max(table.columnCount, 1))

                ForEach(table.rows) { row in
                    GridRow {
                        ForEach(row.cells, id: \.column) { cell in
                            bodyCell(cell)
                                .gridColumnAlignment(alignment(for: cell.column))
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerCell(_ cell: MarkdownDocument.Table.Cell) -> some View {
        Text(cell.content)
            .font(Typography.bodyMedium(fontSize))
            .foregroundStyle(DesignTokens.ink)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func bodyCell(_ cell: MarkdownDocument.Table.Cell) -> some View {
        Text(cell.content)
            .font(Typography.body(fontSize))
            .foregroundStyle(color)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func alignment(for column: Int) -> HorizontalAlignment {
        guard column < table.alignments.count else { return .leading }
        switch table.alignments[column] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
