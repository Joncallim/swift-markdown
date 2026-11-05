/* MostlyText downstream: retain parser-consumed reference syntax and exact uses.
 Copyright (c) 2026 MostlyText contributors.
 Licensed under Apache License v2.0 with Runtime Library Exception.
*/

import Foundation

/// Metadata from one actual CommonMark parse, never a synthesized definition.
@_spi(MostlyText)
public struct ParserReferenceDefinition: Sendable {
    public let identifier: UInt64
    public let source: String
    public let useRanges: [SourceRange]
}

extension Document {
    /// Nil for programmatically reconstructed or structural-directive documents.
    /// Raw logical syntax retains the parser's existing container/newline handling.
    @_spi(MostlyText)
    public var parserReferenceDefinitions: [ParserReferenceDefinition]? {
        _parserReferenceIdentity == _data.id ? _parserReferenceDefinitions : nil
    }
}
