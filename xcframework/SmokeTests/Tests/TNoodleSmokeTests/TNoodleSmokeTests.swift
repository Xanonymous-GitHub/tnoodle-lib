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
    /// Whether the JVM always produced the same move sequence for a seed; see the generator.
    let sequenceIsDeterministic: Bool
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
            sequenceIsDeterministic: fields[3] == "1",
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
            let imageMatches = svgElements(svg) == svgElements(record.svg)
            #expect(imageMatches, "\(record.label): image differs from the JVM\n\(firstDifference(svg, record.svg))")

            if record.sequenceIsDeterministic {
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

/// An SVG's lines as a sorted multiset: every element must match exactly, in any order.
///
/// svglite writes one element per line. Paint order is not stable across processes for every
/// puzzle (MegaminxPuzzle draws its faces by iterating a `HashMap<Face, Path>`, and enum hash
/// codes are identity-based), so comparing in order would fail at random even on two JVMs.
/// The faces never overlap, so the rendered image is the same either way.
private func svgElements(_ svg: String) -> [Substring] {
    svg.split(separator: "\n", omittingEmptySubsequences: false).sorted()
}

/// A short excerpt around the first differing character, so mismatches stay readable.
private func firstDifference(_ actual: String, _ expected: String) -> String {
    let actualChars = Array(actual)
    let expectedChars = Array(expected)
    let index = zip(actualChars, expectedChars).firstIndex { $0 != $1 }
        ?? min(actualChars.count, expectedChars.count)

    func excerpt(_ chars: [Character]) -> String {
        let lower = max(0, index - 40)
        let upper = min(chars.count, index + 40)
        return String(chars[lower..<upper])
    }

    return "first difference at character \(index)\n  actual:   …\(excerpt(actualChars))…\n  expected: …\(excerpt(expectedChars))…"
}
