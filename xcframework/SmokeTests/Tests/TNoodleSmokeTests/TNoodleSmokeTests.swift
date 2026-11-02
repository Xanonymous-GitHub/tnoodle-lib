import Foundation
import Testing
import TNoodle

/// Prefix of every error sentinel returned by the Objective-C wrapper.
private let errorPrefix = "<TNoodle error:"

/// Every `TNoodlePuzzle` case keyed by the Java `PuzzleRegistry` constant it must mirror.
/// Naming each case explicitly also makes this file fail to compile if a case disappears.
private var puzzlesByRegistryName: [String: TNoodlePuzzle] { [
    "TWO": .two,
    "THREE": .three,
    "FOUR": .four,
    "FOUR_FAST": .fourFast,
    "FIVE": .five,
    "SIX": .six,
    "SEVEN": .seven,
    "THREE_NI": .threeNI,
    "FOUR_NI": .fourNI,
    "FIVE_NI": .fiveNI,
    "THREE_FM": .threeFM,
    "PYRA": .pyra,
    "SQ1": .sq1,
    "MEGA": .mega,
    "CLOCK": .clock,
    "SKEWB": .skewb,
    "FTO": .fto,
] }

/// One line of JVM reference output written by `Fixtures/GenerateExpectedScrambles.java`.
private struct ReferenceRecord: Sendable {
    let ordinal: Int32
    let registryName: String
    let seed: Int64
    /// Whether the move sequence, not just the state, is reproducible across platforms;
    /// see `Fixtures/GenerateExpectedScrambles.java`.
    let sequenceIsComparable: Bool
    /// Whether sibling paint order is stable across processes (all but Megaminx).
    let paintOrderIsStable: Bool
    let scramble: String
    let svg: String

    var label: String { "\(registryName) (seed \(seed))" }
}

private enum ReferenceData {
    static let environmentKey = "TNOODLE_EXPECTED_SCRAMBLES"

    static func load() throws -> [ReferenceRecord] {
        let path = try #require(
            ProcessInfo.processInfo.environment[environmentKey],
            "Run xcframework/test.bash, which generates the JVM reference data and sets \(environmentKey)."
        )
        let records = try String(contentsOfFile: path, encoding: .utf8)
            .split(separator: "\n")
            .map(parse)
        try #require(!records.isEmpty, "Reference data at \(path) is empty.")
        return records
    }

    private static func parse(_ line: Substring) throws -> ReferenceRecord {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        try #require(fields.count == 7, "Malformed reference line: \(line.prefix(80))")

        return ReferenceRecord(
            ordinal: try #require(Int32(fields[0])),
            registryName: String(fields[1]),
            seed: try #require(Int64(fields[2])),
            sequenceIsComparable: fields[3] == "1",
            paintOrderIsStable: fields[4] == "1",
            scramble: try decodeBase64(fields[5]),
            svg: try decodeBase64(fields[6])
        )
    }

    private static func decodeBase64(_ field: Substring) throws -> String {
        let data = try #require(Data(base64Encoded: String(field)))
        return try #require(String(data: data, encoding: .utf8))
    }
}

// Serialized: the translated scramblers are exercised the way apps typically call them, and
// several of them build large solver tables lazily on first use.
@Suite("TNoodle XCFramework", .serialized)
struct TNoodleSmokeTests {
    @Test("TNoodlePuzzle raw values mirror the Java PuzzleRegistry ordinals")
    func puzzleEnumMirrorsRegistry() throws {
        var ordinalsByName: [String: Int32] = [:]
        for record in try ReferenceData.load() {
            ordinalsByName[record.registryName] = record.ordinal
        }

        #expect(Set(ordinalsByName.keys) == Set(puzzlesByRegistryName.keys))
        for (name, ordinal) in ordinalsByName.sorted(by: { $0.value < $1.value }) {
            #expect(puzzlesByRegistryName[name]?.rawValue == ordinal, "\(name)")
        }
    }

    @Test("Scrambles reach the same states as on the JVM, with identical images")
    func scramblesMatchJVM() throws {
        for record in try ReferenceData.load() {
            let puzzle = try #require(puzzlesByRegistryName[record.registryName], "\(record.label)")
            let scramble = TNoodle.generateWcaScramble(puzzle, seed: record.seed)

            guard !scramble.hasPrefix(errorPrefix) else {
                Issue.record("\(record.label): \(scramble)")
                continue
            }

            // The image depends only on the scrambled state, so its elements must always match.
            let svg = TNoodle.drawScramble(puzzle, scramble: scramble, colorScheme: nil)
            let ordered = record.paintOrderIsStable
            let actual = try #require(SVGStructure(svg, preservingOrder: ordered), "\(record.label): not well-formed SVG")
            let expected = try #require(
                SVGStructure(record.svg, preservingOrder: ordered),
                "\(record.label): bad reference SVG"
            )
            let imageMatches = actual == expected
            #expect(imageMatches, "\(record.label): image differs from the JVM\n\(actual.difference(from: expected))")

            if record.sequenceIsComparable {
                #expect(scramble == record.scramble, "\(record.label)")
            }
        }
    }

    @Test("FTO scrambles use FTO notation and are reproducible from a seed")
    func ftoScrambles() {
        let ftoMoves: Set<Substring> = [
            "U", "R", "F", "L", "B", "BL", "D", "BR",
            "U'", "R'", "F'", "L'", "B'", "BL'", "D'", "BR'",
        ]

        for seed in Int64(0)..<5 {
            let scramble = TNoodle.generateWcaScramble(.fto, seed: seed)
            let moves = scramble.split(separator: " ")

            #expect(!moves.isEmpty, "seed \(seed): \(scramble)")
            #expect(moves.allSatisfy(ftoMoves.contains), "seed \(seed): \(scramble)")
            #expect(TNoodle.generateWcaScramble(.fto, seed: seed) == scramble, "seed \(seed)")
        }
    }

    @Test("Puzzle values without a Java counterpart return an error sentinel")
    func unknownPuzzleReturnsError() throws {
        let unknown = try #require(TNoodlePuzzle(rawValue: 999))

        let scramble = TNoodle.generateWcaScramble(unknown, seed: 1)
        let image = TNoodle.drawScramble(unknown, scramble: nil, colorScheme: nil)

        #expect(scramble.hasPrefix(errorPrefix), "\(scramble)")
        #expect(image.hasPrefix(errorPrefix), "\(image)")
    }

    @Test("Malformed color schemes return an error sentinel")
    func invalidColorSchemeReturnsError() {
        // Two colors for a six-faced puzzle.
        let image = TNoodle.drawScramble(.three, scramble: nil, colorScheme: "red,green")

        #expect(image == "<TNoodle error: invalid color scheme>")
    }
}

/// An SVG reduced to what its image depends on: its elements in paint order, each identified
/// by its depth, name, attributes (sorted by name) and text. Every value must match exactly.
///
/// Only differences that cannot change the rendered image are normalized away, because none of
/// them is stable across runtimes:
/// - attribute order, which XML defines as insignificant, and the order of CSS declarations in
///   `style`; svglite keeps both in a `HashMap`, which the JVM and J2ObjC's emulated JRE iterate
///   differently;
/// - paint order, but only where the reference marks it unstable: MegaminxPuzzle draws its
///   non-overlapping faces by iterating a `HashMap<Face, Path>`, whose order varies even between
///   JVM runs. Everywhere else it matters (Clock's hands and pins overlap) and is compared;
/// - floating-point noise below 1e-4 px: Java permits `Math.sin`/`cos` a 1 ulp error, and the
///   JVM's intrinsics and Apple's libm (which J2ObjC calls) round the last digits differently.
private struct SVGStructure: Equatable {
    let elements: [String]

    init?(_ svg: String, preservingOrder: Bool) {
        let collector = ElementCollector()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = collector
        guard parser.parse() else { return nil }
        elements = preservingOrder ? collector.signatures : collector.signatures.sorted()
    }

    /// The first differing position, so mismatches stay readable; also says whether the two
    /// sides hold the same elements in a different order.
    func difference(from expected: SVGStructure) -> String {
        let index = zip(elements, expected.elements).enumerated()
            .first { $0.element.0 != $0.element.1 }?.offset
            ?? min(elements.count, expected.elements.count)
        let sameElements = elements.sorted() == expected.elements.sorted()
        func element(_ list: [String]) -> Substring {
            index < list.count ? list[index].prefix(240) : "<none>"
        }
        return """
            \(elements.count) elements vs \(expected.elements.count) expected\(sameElements ? " (same elements, different order)" : "")
              first difference at element \(index)
              actual:   \(element(elements))
              expected: \(element(expected.elements))
            """
    }
}

private final class ElementCollector: NSObject, XMLParserDelegate {
    private(set) var signatures: [String] = []
    private var open: [(signature: String, text: String)] = []

    /// Decimal numbers not part of an identifier or a `#rrggbb` color.
    private let number = try! NSRegularExpression(pattern: #"(?<![#\w.])-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?"#)

    private func normalized(_ value: String, attribute: String) -> String {
        var value = value
        if attribute == "style" {
            value = value.split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted()
                .joined(separator: "; ")
        }

        let source = value as NSString
        var result = ""
        var cursor = 0
        for match in number.matches(in: value, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let rounded = String(format: "%.4f", Double(source.substring(with: match.range)) ?? .nan)
            result += rounded == "-0.0000" ? "0.0000" : rounded
            cursor = match.range.location + match.range.length
        }
        return result + source.substring(from: cursor)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let sortedAttributes = attributes
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(normalized($0.value, attribute: $0.key))" }
            .joined(separator: " ")
        open.append(("\(open.count)|\(elementName)|\(sortedAttributes)", ""))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !open.isEmpty else { return }
        open[open.count - 1].text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard let element = open.popLast() else { return }
        let text = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        signatures.append("\(element.signature)|\(text)")
    }
}
