# Keep the Markdown API while correcting original source coordinates

This child starts at exact Swift Markdown0.8.0 source recorded in the manifest.
Every library Sources file, original LICENSE and NOTICE is byte-identical.
Only the C runtime dependency is pinned to the qualified original-source owner;
public Markdown APIs and parsed document semantics remain unchanged.

The existing malformed-directive snapshot expected a closing brace at line3
column3 although its authored byte is at column1. Correct those two expected
range strings and retain every assertion. A new direct authored-byte oracle
proves the brace range independently. Six new Swift Testing functions cover
Unicode, all line endings, varying/lazy container prefixes, paragraph/table
coordinates, removed reference definitions, multiline code/HTML and escaped
pipes. Initial failures are retained with the application evidence.

Qualification: all299 upstream XCTest and6 new functions pass Debug/Release;
actual application MarkdownEngine158 functions pass Debug/Release. Original/
candidate AST content, formatted Markdown and every HTML byte except generated
source-position attributes match for9054 cases. The same complete AST/format
outputs match under AddressSanitizer. Original C API668 checks pass normally,
with AddressSanitizer and with UndefinedBehaviorSanitizer. All original strict
spec/regression/GFM/smart-punctuation outputs pass. Consult the C owner's patch
manifest for implementation/provenance and the application receipt for full logs.

This is a narrow source-metadata dependency correction, not upstream acceptance,
production math activation, native visual/VoiceOver or complete-editor performance
acceptance. Application adoption still requires exact pins and full hosted CI.
