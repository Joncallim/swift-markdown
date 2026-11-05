/* MostlyText downstream: parser-owned reference replay and source identity. */
import Foundation
@_spi(MostlyText) @testable import Markdown
import Testing

@Suite("Parser-owned reference definitions")
struct ParserReferenceDefinitionTests {
    private func referenceNodes(_ node: any Markup) -> [any Markup] {
        if node is Link || node is Image { return [node] + node.children.flatMap(referenceNodes) }
        return node.children.flatMap(referenceNodes)
    }

    @Test(arguments: ["\n", "\r\n", "\r"])
    func onlyConsumedDefinitionsAndActualFinalUseRangesEscapeTheParser(_ ending: String) throws {
        let raw = "```\n[fake]: /wrong\n```\n\n<div>\n[html]: /wrong\n</div>\n\n" +
            "> - [key]:\n>     /right\n>     \"title\"\n\n[visible][key] ![image][key] [direct](/direct)"
        let source = raw.replacingOccurrences(of: "\n", with: ending)
        let document = Document(parsing: source)
        let definitions = try #require(document.parserReferenceDefinitions)
        try #require(definitions.count == 1)
        let definition = try #require(definitions.first)
        #expect(definition.identifier > 0)
        #expect(definition.source.contains("[key]:"))
        #expect(definition.source.contains("/right"))
        #expect(!definition.source.contains("fake") && !definition.source.contains("html"))
        let references = referenceNodes(document)
        let expected = references.filter { node in
            if let link = node as? Link { return link.destination == "/right" }
            return (node as? Image)?.source == "/right"
        }.compactMap(\.range)
        #expect(expected.count == 2)
        #expect(Set(definition.useRanges) == Set(expected))
        let replay = Document(parsing: definition.source + "\n\n[visible][key] ![image][key]")
        let replayNodes = referenceNodes(replay)
        #expect(replayNodes.count == 2)
        #expect((replayNodes.first as? Link)?.destination == "/right")
        #expect((replayNodes.first as? Link)?.title == "title")
    }

    @Test func firstDuplicateWinsAndUnusedDefinitionsHaveNoFabricatedUses() throws {
        let source = "[key]: /first\n[key]: /later\n[unused]: /unused\n\n[one][key] [two][key]"
        let document = Document(parsing: source)
        let records = try #require(document.parserReferenceDefinitions)
        #expect(records.count == 3)
        #expect(Set(records.map(\.identifier)).count == 3)
        #expect(records.map { $0.useRanges.count } == [2, 0, 0])
        #expect(records[0].source.contains("/first"))
        #expect(records[1].source.contains("/later"))
        #expect(referenceNodes(document).allSatisfy { ($0 as? Link)?.destination == "/first" })
    }

    @Test func metadataCopiesSurviveCFreeButCannotAuthorizeAReconstructedOrMutatedDocument() throws {
        let original = Document(parsing: "[key]: /right\n\n[text][key]")
        let retained = try #require(original.parserReferenceDefinitions)
        #expect(retained.first?.source.contains("/right") == true)
        let copied = original
        #expect(copied.parserReferenceDefinitions?.count == 1)
        let rebuilt = Document(original.blockChildren)
        #expect(rebuilt.parserReferenceDefinitions == nil)
        var changed = original
        changed.setBlockChildren([Paragraph(Markdown.Text("changed"))] as [any BlockMarkup])
        #expect(changed.parserReferenceDefinitions == nil)
        #expect(changed._parserReferenceDefinitions == nil, "Invalidated metadata must be released promptly")
        #expect(original.parserReferenceDefinitions?.count == 1)
        #expect(retained.first?.source.contains("/right") == true)
    }

    @Test func structuralDirectiveDocumentsAndDisabledPositionsDoNotClaimWholeSourceUseAuthority() throws {
        let source = "[key]: /right\n\n[text][key]"
        let structural = Document(parsing: source, options: [.parseBlockDirectives])
        #expect(structural.parserReferenceDefinitions == nil)
        let noPositions = Document(parsing: source, options: [.disableSourcePosOpts])
        #expect(noPositions.parserReferenceDefinitions?.first?.useRanges.isEmpty == true)
        let noDefinitions = Document(parsing: "ordinary text")
        #expect(noDefinitions.parserReferenceDefinitions?.isEmpty == true)
    }
}
