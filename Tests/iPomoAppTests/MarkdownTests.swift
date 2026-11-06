import Foundation
import Testing
@testable import iPomoUI

@Suite struct MarkdownDocumentTests {
    private func text(_ content: AttributedString) -> String {
        String(content.characters)
    }

    private func text(_ content: AttributedSubstring) -> String {
        String(content.characters)
    }

    @Test func emptyInputProducesNoBlocks() {
        #expect(MarkdownDocument.parse("").blocks.isEmpty)
        #expect(MarkdownDocument.parse("   \n\n\t").blocks.isEmpty)
    }

    @Test func parsesHeadingsAndParagraphs() throws {
        let document = MarkdownDocument.parse("# Title\n\n## Second\n\nBody **bold** text.")

        #expect(document.blocks.count == 3)

        let first = try #require(document.blocks.first)
        guard case .heading(let firstLevel) = first.kind else {
            Issue.record("Expected first block to be a heading")
            return
        }
        #expect(firstLevel == 1)
        #expect(text(first.content) == "Title")

        guard case .heading(let secondLevel) = document.blocks[1].kind else {
            Issue.record("Expected second block to be a heading")
            return
        }
        #expect(secondLevel == 2)

        guard case .paragraph = document.blocks[2].kind else {
            Issue.record("Expected third block to be a paragraph")
            return
        }
        #expect(text(document.blocks[2].content) == "Body bold text.")

        let bold = document.blocks[2].content.runs.first {
            text(document.blocks[2].content[$0.range]) == "bold"
        }
        #expect(bold?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
    }

    @Test func joinsSoftLineBreaksInsideAParagraph() {
        let document = MarkdownDocument.parse("Line one\nline two\n\nNew paragraph.")

        #expect(document.blocks.count == 2)
        #expect(text(document.blocks[0].content) == "Line one line two")
        #expect(text(document.blocks[1].content) == "New paragraph.")
    }

    @Test func parsesBulletAndOrderedLists() {
        let document = MarkdownDocument.parse("- one\n- two\n\n1. first\n2. second")

        #expect(document.blocks.count == 4)

        if case .listItem(let depth, let marker) = document.blocks[0].kind {
            #expect(depth == 1)
            #expect(marker == .bullet)
        } else {
            Issue.record("Expected a bullet list item")
        }
        #expect(text(document.blocks[0].content) == "one")

        if case .listItem(let depth, let marker) = document.blocks[2].kind {
            #expect(depth == 1)
            #expect(marker == .ordered(1))
        } else {
            Issue.record("Expected an ordered list item")
        }
        #expect(text(document.blocks[2].content) == "first")

        if case .listItem(_, let marker) = document.blocks[3].kind {
            #expect(marker == .ordered(2))
        } else {
            Issue.record("Expected an ordered list item")
        }
    }

    @Test func parsesNestedListDepths() {
        let document = MarkdownDocument.parse("- outer\n  - inner\n  - inner two")

        #expect(document.blocks.count == 3)

        let depths: [Int] = document.blocks.compactMap { block in
            guard case .listItem(let depth, _) = block.kind else { return nil }
            return depth
        }
        #expect(depths == [1, 2, 2])
    }

    @Test func parsesTaskListMarkersAndStripsThemFromContent() {
        let document = MarkdownDocument.parse("- [ ] todo\n- [x] done")

        #expect(document.blocks.count == 2)

        if case .listItem(let depth, let marker) = document.blocks[0].kind {
            #expect(depth == 1)
            #expect(marker == .task(checked: false))
        } else {
            Issue.record("Expected a task list item")
        }
        #expect(text(document.blocks[0].content) == "todo")

        if case .listItem(_, let marker) = document.blocks[1].kind {
            #expect(marker == .task(checked: true))
        } else {
            Issue.record("Expected a checked task list item")
        }
        #expect(text(document.blocks[1].content) == "done")
    }

    @Test func parsesFencedCodeBlocks() {
        let document = MarkdownDocument.parse("```swift\nlet x = 1\nprint(x)\n```")

        #expect(document.blocks.count == 1)
        guard case .codeBlock(let language) = document.blocks[0].kind else {
            Issue.record("Expected a code block")
            return
        }
        #expect(language == "swift")
        #expect(text(document.blocks[0].content) == "let x = 1\nprint(x)")
    }

    @Test func parsesBlockQuotes() {
        let document = MarkdownDocument.parse("> quoted\n> second line")

        #expect(document.blocks.count == 1)
        #expect(document.blocks[0].quoteDepth == 1)
        #expect(document.blocks[0].quoteID != nil)
        if case .paragraph = document.blocks[0].kind {
            // Expected: a quoted paragraph
        } else {
            Issue.record("Expected a quoted paragraph")
        }
        #expect(text(document.blocks[0].content) == "quoted second line")
    }

    @Test func parsesThematicBreaks() {
        let document = MarkdownDocument.parse("Above\n\n---\n\nBelow")

        #expect(document.blocks.count == 3)
        if case .thematicBreak = document.blocks[1].kind {
            // Expected
        } else {
            Issue.record("Expected a thematic break")
        }
    }

    @Test func parsesTablesWithHeaderRowsAndAlignment() throws {
        let document = MarkdownDocument.parse(
            """
            | Name | Count |
            |:-----|------:|
            | **A** | 1 |
            | B | 2 |
            """
        )

        #expect(document.blocks.count == 1)
        guard case .table(let table) = document.blocks[0].kind else {
            Issue.record("Expected a table")
            return
        }

        #expect(table.columnCount == 2)
        #expect(table.alignments == [.leading, .trailing])
        #expect(table.header.map { text($0.content) } == ["Name", "Count"])
        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.map { text($0.content) } == ["A", "1"])
        #expect(table.rows[1].cells.map { text($0.content) } == ["B", "2"])

        let boldCell = table.rows[0].cells[0]
        let bold = boldCell.content.runs.first {
            text(boldCell.content[$0.range]) == "A"
        }
        #expect(bold?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
    }

    @Test func preservesInlineFormattingAndLinks() throws {
        let document = MarkdownDocument.parse(
            "Mix **bold**, *italic*, `code`, ~~strike~~, and [link](https://example.com)."
        )

        #expect(document.blocks.count == 1)
        let content = document.blocks[0].content

        func range(of needle: String) -> Range<AttributedString.Index>? {
            content.runs.first { text(content[$0.range]) == needle }?.range
        }

        #expect(range(of: "bold").map { content[$0].inlinePresentationIntent?.contains(.stronglyEmphasized) } == true)
        #expect(range(of: "italic").map { content[$0].inlinePresentationIntent?.contains(.emphasized) } == true)
        #expect(range(of: "code").map { content[$0].inlinePresentationIntent?.contains(.code) } == true)
        #expect(range(of: "strike").map { content[$0].inlinePresentationIntent?.contains(.strikethrough) } == true)

        let link = try #require(range(of: "link"))
        #expect(content[link].link == URL(string: "https://example.com"))
    }

    @Test func malformedMarkdownStillProducesReadableBlocks() {
        let unclosedBold = MarkdownDocument.parse("**unclosed bold")
        #expect(!unclosedBold.blocks.isEmpty)
        #expect(text(unclosedBold.blocks[0].content).contains("unclosed bold"))

        let unclosedFence = MarkdownDocument.parse("```\nlet x = 1")
        #expect(!unclosedFence.blocks.isEmpty)
    }

    @Test func cachedParsingMatchesDirectParsing() {
        let source = "# Cached\n\n- one\n- two"

        let direct = MarkdownDocument.parse(source)
        let cached = MarkdownDocument.cached(source)

        #expect(cached.blocks.map { text($0.content) } == direct.blocks.map { text($0.content) })
    }
}
