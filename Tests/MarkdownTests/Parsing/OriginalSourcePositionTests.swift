import Foundation
@testable import Markdown
import Testing

struct OriginalSourcePositionTests {
    private func descendants(_ root: any Markup) -> [any Markup] {
        var result: [any Markup] = []
        var pending: [any Markup] = [root]
        while let node = pending.popLast() {
            result.append(node)
            pending.append(contentsOf: node.children.reversed())
        }
        return result
    }

    private func point(_ prefix: String) -> Markdown.SourceLocation {
        var line = 1
        var column = 1
        var previousCR = false
        for scalar in prefix.unicodeScalars {
            if scalar.value == 13 { line += 1; column = 1; previousCR = true }
            else if scalar.value == 10 {
                if !previousCR { line += 1 }
                column = 1; previousCR = false
            } else { column += scalar.utf8.count; previousCR = false }
        }
        return Markdown.SourceLocation(line: line, column: column, source: nil)
    }

    private func expected(_ authored: String, in source: String) throws -> SourceRange {
        let ns = source as NSString
        let found = ns.range(of: authored, options: .literal)
        #expect(found.location != NSNotFound)
        guard found.location != NSNotFound else { throw MissingAuthoredRange() }
        return point(ns.substring(to: found.location)) ..< point(ns.substring(to: NSMaxRange(found)))
    }

    private struct MissingAuthoredRange: Error {}

    @Test(arguments: ["\n", "\r\n", "\r"])
    func continuationPositionsUseOriginalBytes(ending: String) throws {
        for (first, second) in [("> before", "lazy $x$"), ("> before", ">     $x$"),
                                ("- before", "    $x$"), ("> - before", ">      $x$"),
                                ("> 漢😀", ">\t$x$")] {
            let source = first + ending + second
            let nodes = descendants(Document(parsing: source))
            let raw = second == "lazy $x$" ? second : "$x$"
            let text = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == raw })
            #expect(text.range == (try expected(raw, in: source)), "\(source.debugDescription)")
        }
    }

    @Test(arguments: ["\n", "\r\n", "\r"])
    func paragraphAndTableHeaderHaveOriginalCoordinates(ending: String) throws {
        for prefix in ["", "> ", "  "] {
            let source = ["漢😀 before $p$", "| $a$ | B |", "|---|---|", "| $x$ | $y$ |"]
                .map { prefix + $0 }.joined(separator: ending)
            let nodes = descendants(Document(parsing: source))
            for raw in ["漢😀 before $p$", "$a$", "B", "$x$", "$y$"] {
                let text = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == raw })
                #expect(text.range == (try expected(raw, in: source)), "\(source.debugDescription) raw=\(raw)")
            }
        }
    }

    @Test(arguments: ["\n", "\r\n", "\r"])
    func referenceDefinitionRemovalKeepsFollowingTextOnItsOriginalLine(ending: String) throws {
        let source = "[key]: /target" + ending + "prose $x$ and [link][key]"
        let nodes = descendants(Document(parsing: source))
        let text = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == "prose $x$ and " })
        let link = try #require(nodes.compactMap { $0 as? Link }.first)
        #expect(text.range == (try expected("prose $x$ and ", in: source)))
        #expect(link.range == (try expected("[link][key]", in: source)))
        #expect(link.destination == "/target")
    }

    @Test(arguments: ["\n", "\r\n", "\r"])
    func multilineCodeAndHTMLUseTheRealEndColumn(ending: String) throws {
        for raw in ["`a" + ending + ">     b`", "<span" + ending + ">     title='x'>"] {
            let source = "> before " + raw + " after"
            let nodes = descendants(Document(parsing: source))
            let node = try #require(nodes.first { $0 is InlineCode || $0 is InlineHTML })
            let wanted = try expected(raw, in: source)
            #expect(node.range == wanted, "\(source.debugDescription); actual=\(String(describing: node.range)); wanted=\(wanted)")
        }
    }

    @Test func directiveContinuationUsesTheAuthoredClosingBraceColumn() throws {
        let source = "@Outer(x: 1)\n  Not a part of `Outer`.\n}"
        let nodes = descendants(Document(parsing: source, options: .parseBlockDirectives))
        let brace = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == "}" })
        #expect(brace.range == (try expected("}", in: source)))
    }

    @Test func unescapedTablePipesKeepTheRemainingRawCoordinates() throws {
        let source = "| A | B |\n|---|---|\n| \\| [$x$](/target) | $y$ |"
        let nodes = descendants(Document(parsing: source))
        let link = try #require(nodes.compactMap { $0 as? Link }.first)
        let math = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == "$x$" })
        let last = try #require(nodes.compactMap { $0 as? Markdown.Text }.first { $0.string == "$y$" })
        #expect(link.range == (try expected("[$x$](/target)", in: source)))
        #expect(math.range == (try expected("$x$", in: source)))
        #expect(last.range == (try expected("$y$", in: source)))
    }
}
