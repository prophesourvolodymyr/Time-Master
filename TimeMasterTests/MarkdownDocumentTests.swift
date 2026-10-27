import XCTest
@testable import TimeMaster

final class MarkdownDocumentTests: XCTestCase {
    private func kinds(_ doc: MarkdownDocument) -> String {
        doc.blocks.map { block -> String in
            switch block.kind {
            case .paragraph: return "p"
            case .heading(let level): return "h\(level)"
            case .bullet: return "b\(block.indent)"
            case .numbered: return "n\(block.indent)"
            case .todo(let done): return done ? "t+\(block.indent)" : "t\(block.indent)"
            case .quote: return "q"
            case .code(let language): return "c:\(language)"
            case .divider: return "-"
            case .image: return "img"
            case .linkCard(_, let thumbnail): return thumbnail == nil ? "card" : "card+"
            }
        }.joined(separator: " ")
    }

    private let sample = """
    # Title

    Some **bold** text and a [link](https://example.com).
    Second soft line.

    - one
    - two
      - nested
        - deeper
    - [ ] todo
    - [x] done

    1. first
    2. second
       1. inner

    > quote line
    > second quote line

    ```swift
    let x = 1

    let y = 2
    ```

    ---

    ![photo](<Attachments/a b.jpg>)

    [![Video \\[title\\]](<https://img.youtube.com/vi/abc/mqdefault.jpg>)](<https://youtu.be/abc>)

    [Instagram post](<https://www.instagram.com/p/XYZ/> "card")

    Last paragraph
    """

    func testParsesEveryBlockKind() {
        let doc = MarkdownDocument(markdown: sample)
        XCTAssertEqual(kinds(doc), "h1 p b0 b0 b1 b2 t0 t+0 n0 n0 n1 q c:swift - img card+ card p")
        XCTAssertEqual(doc.blocks[1].text, "Some **bold** text and a [link](https://example.com).\nSecond soft line.")
        XCTAssertEqual(doc.blocks[12].text, "let x = 1\n\nlet y = 2")
        guard case .image(let path) = doc.blocks[14].kind else { return XCTFail("expected an image block") }
        XCTAssertEqual(path, "Attachments/a b.jpg")
        guard case .linkCard(let url, let thumbnail) = doc.blocks[15].kind else { return XCTFail("expected a link card") }
        XCTAssertEqual(url, "https://youtu.be/abc")
        XCTAssertEqual(thumbnail, "https://img.youtube.com/vi/abc/mqdefault.jpg")
        XCTAssertEqual(doc.blocks[15].text, "Video [title]")
    }

    func testSerializationSurvivesRoundTrips() {
        let doc = MarkdownDocument(markdown: sample)
        let out = doc.markdown
        let again = MarkdownDocument(markdown: out)
        XCTAssertEqual(kinds(again), kinds(doc))
        XCTAssertEqual(again.blocks.map(\.text), doc.blocks.map(\.text))
        XCTAssertEqual(again.markdown, out)
    }

    func testNumberedListsRestartAfterAnotherBlock() {
        var doc = MarkdownDocument(markdown: "1. a\n2. b\n3. c")
        XCTAssertEqual(doc.numberedPosition(at: 2), 3)
        XCTAssertEqual(doc.markdown, "1. a\n2. b\n3. c")
        doc.blocks.insert(MarkdownBlock(kind: .bullet, text: "x"), at: 2)
        XCTAssertEqual(doc.markdown, "1. a\n2. b\n\n- x\n\n1. c")
    }

    func testCodeFenceGrowsWhenBodyContainsAFence() {
        let doc = MarkdownDocument(blocks: [MarkdownBlock(kind: .code("md"), text: "```\ninner\n```")])
        let out = doc.markdown
        XCTAssertTrue(out.hasPrefix("````md"))
        XCTAssertEqual(MarkdownDocument(markdown: out).blocks.first?.text, "```\ninner\n```")
    }

    func testSplitAndMergeKeepTextAndCaret() {
        var doc = MarkdownDocument(markdown: "Hello world")
        let caret = doc.splitBlock(id: doc.blocks[0].id, caret: 5)
        XCTAssertEqual(doc.blocks.map(\.text), ["Hello", " world"])
        XCTAssertEqual(caret?.blockID, doc.blocks[1].id)
        XCTAssertEqual(caret?.location, 0)
        let merged = doc.deleteBackwardAtStart(id: doc.blocks[1].id)
        XCTAssertEqual(doc.blocks.map(\.text), ["Hello world"])
        XCTAssertEqual(merged?.location, 5)
    }

    func testSplitCountsUTF16CaretOffsets() {
        var doc = MarkdownDocument(markdown: "a😀b")
        _ = doc.splitBlock(id: doc.blocks[0].id, caret: 3)
        XCTAssertEqual(doc.blocks.map(\.text), ["a😀", "b"])
    }

    func testListReturnIndentAndBackspace() {
        var list = MarkdownDocument(markdown: "- a\n- b")
        _ = list.splitBlock(id: list.blocks[1].id, caret: 1)
        XCTAssertEqual(kinds(list), "b0 b0 b0", "Return continues the list")
        _ = list.splitBlock(id: list.blocks[2].id, caret: 0)
        XCTAssertEqual(kinds(list), "b0 b0 p", "Return on an empty item leaves the list")
        list.changeIndent(id: list.blocks[1].id, by: 1)
        XCTAssertEqual(list.blocks[1].indent, 1)
        list.changeIndent(id: list.blocks[0].id, by: 1)
        XCTAssertEqual(list.blocks[0].indent, 0, "the first item cannot be indented")
        _ = list.deleteBackwardAtStart(id: list.blocks[1].id)
        XCTAssertEqual(list.blocks[1].indent, 0, "Backspace outdents first")
        _ = list.deleteBackwardAtStart(id: list.blocks[1].id)
        XCTAssertEqual(list.blocks[1].kind, .paragraph, "then converts to a paragraph")
    }

    func testTypedPrefixesConvertOnlyWhenTheCaretFollowsThem() {
        func converted(_ typed: String, caret: Int? = nil, kind: MarkdownBlock.Kind = .paragraph) -> String {
            var doc = MarkdownDocument(blocks: [MarkdownBlock(kind: kind, text: typed)])
            _ = doc.applyShortcut(id: doc.blocks[0].id, caret: caret ?? (typed as NSString).length)
            return kinds(doc)
        }
        XCTAssertEqual(converted("# "), "h1")
        XCTAssertEqual(converted("## "), "h2")
        XCTAssertEqual(converted("### "), "h3")
        XCTAssertEqual(converted("- "), "b0")
        XCTAssertEqual(converted("1. "), "n0")
        XCTAssertEqual(converted("[] "), "t0")
        XCTAssertEqual(converted("[x] "), "t+0")
        XCTAssertEqual(converted("> "), "q")
        XCTAssertEqual(converted("```"), "c:")
        XCTAssertEqual(converted("---"), "- p")
        XCTAssertEqual(converted("[] ", kind: .bullet), "t0")
        XCTAssertEqual(converted("# Heading text", caret: 14), "p")
        XCTAssertEqual(converted("#nospace"), "p")
    }
}

@MainActor
final class MarkdownEditorSessionTests: XCTestCase {
    func testPastedLinkIsOfferedAsCardAndKeepsItsAddress() {
        let session = MarkdownEditorSession(markdown: "")
        session.fetchMetadata = { _ in nil }
        var emitted = ""
        session.onEmit = { emitted = $0 }
        let id = session.document.blocks[0].id
        let address = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        XCTAssertFalse(session.pasteString(id, string: address, selection: NSRange(location: 0, length: 0)), "the link is inserted as text first")
        XCTAssertEqual(session.pasteOffer?.url.absoluteString, address)
        session.textChanged(id, text: address, selection: NSRange(location: address.count, length: 0))
        session.acceptOffer()
        XCTAssertNil(session.pasteOffer)
        guard case .linkCard(let url, _) = session.document.blocks[0].kind else { return XCTFail("the pasted line becomes a card") }
        XCTAssertEqual(url, address)
        XCTAssertTrue(session.document.blocks.last?.isParagraph == true, "a paragraph follows the card")
        XCTAssertTrue(emitted.contains("<\(address)>"))
    }

    func testDismissingTheOfferKeepsThePlainLink() {
        let session = MarkdownEditorSession(markdown: "")
        session.fetchMetadata = { _ in nil }
        let id = session.document.blocks[0].id
        let address = "https://example.com/page"
        _ = session.pasteString(id, string: address, selection: NSRange(location: 0, length: 0))
        session.textChanged(id, text: address, selection: NSRange(location: address.count, length: 0))
        session.dismissOffer()
        XCTAssertNil(session.pasteOffer)
        XCTAssertEqual(session.document.blocks[0].text, address)
        XCTAssertTrue(session.document.blocks[0].isParagraph)
    }

    func testMultiLineMarkdownPasteBecomesBlocks() {
        let session = MarkdownEditorSession(markdown: "")
        let id = session.document.blocks[0].id
        XCTAssertTrue(session.pasteString(id, string: "# Plan\n\n- squat\n- press\n\nDone", selection: NSRange(location: 0, length: 0)))
        let kinds = session.document.blocks.map(\.kind)
        XCTAssertEqual(kinds.first, .heading(1))
        XCTAssertEqual(kinds.filter { $0 == .bullet }.count, 2)
        XCTAssertEqual(session.document.markdown, "# Plan\n\n- squat\n- press\n\nDone")
    }

    func testSlashMenuFiltersAndAppliesBlockKinds() {
        let session = MarkdownEditorSession(markdown: "")
        let id = session.document.blocks[0].id
        session.textChanged(id, text: "/head", selection: NSRange(location: 5, length: 0))
        XCTAssertEqual(session.slash?.query, "head")
        XCTAssertEqual(MarkdownSlashItem.matches("head").map(\.id), ["h1", "h2", "h3"])
        guard let item = MarkdownSlashItem.matches("head").first else { return XCTFail("no slash match") }
        session.apply(item)
        XCTAssertNil(session.slash)
        XCTAssertEqual(session.document.blocks[0].kind, .heading(1))
        XCTAssertEqual(session.document.blocks[0].text, "")
    }
}
