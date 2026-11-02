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
        try #require(fields.count == 6, "Malformed reference line: \(line.prefix(80))")

        return ReferenceRecord(
            ordinal: try #require(Int32(fields[0])),
            registryName: String(fields[1]),
            seed: try #require(Int64(fields[2])),
            sequenceIsComparable: fields[3] == "1",
            scramble: try decodeBase64(fields[4]),
            svg: try decodeBase64(fields[5])
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
            let actual = try #require(SVGStructure(svg), "\(record.label): not well-formed SVG")
            let expected = try #require(SVGStructure(record.svg), "\(record.label): bad reference SVG")
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

/// An SVG reduced to what its image depends on: a sorted multiset of elements, each identified
/// by its depth, name, attributes (sorted by name) and text. Every value must match exactly.
///
/// Two orderings are deliberately ignored, because neither is stable across runtimes:
/// - attribute order, which XML defines as insignificant; svglite keeps attributes in a
///   `HashMap`, which the JVM and J2ObjC's emulated JRE iterate differently;
/// - sibling order, which only affects paint order; MegaminxPuzzle draws its non-overlapping
///   faces by iterating a `HashMap<Face, Path>`, whose order varies even between JVM runs.
private struct SVGStructure: Equatable {
    let elements: [String]

    init?(_ svg: String) {
        let collector = ElementCollector()
        let parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = collector
        guard parser.parse() else { return nil }
        elements = collector.signatures.sorted()
    }

    /// The first element present on one side only, so mismatches stay readable.
    func difference(from expected: SVGStructure) -> String {
        let actualOnly = elements.first { !expected.elements.contains($0) } ?? "-"
        let expectedOnly = expected.elements.first { !elements.contains($0) } ?? "-"
        return """
            \(elements.count) elements vs \(expected.elements.count) expected
              only in actual:   \(actualOnly.prefix(240))
              only in expected: \(expectedOnly.prefix(240))
            """
    }
}

private final class ElementCollector: NSObject, XMLParserDelegate {
    private(set) var signatures: [String] = []
    private var open: [(signature: String, text: String)] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let sortedAttributes = attributes
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
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
