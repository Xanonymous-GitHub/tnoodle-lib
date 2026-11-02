import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Random;

import org.worldcubeassociation.tnoodle.scrambles.Puzzle;
import org.worldcubeassociation.tnoodle.scrambles.PuzzleRegistry;

/**
 * Writes the JVM reference output that the XCFramework smoke tests compare against.
 *
 * <p>For every {@link PuzzleRegistry} entry and every seed, this mirrors what {@code TNoodle.m}
 * does on Apple platforms: {@code generateWcaScramble(new Random(seed))} followed by
 * {@code drawScramble(scramble, parseColorScheme(null))}.
 *
 * <p>A seed always determines the scrambled <em>state</em>, so the SVG of that state must match
 * byte for byte on every platform. It does not always determine the <em>move sequence</em>:
 * some official solvers (Pyraminx, Skewb) pick among equally short solutions with their own
 * unseeded {@code Random}. Each puzzle is therefore generated {@value #RUNS_PER_SEED} times per
 * seed, and the move sequence is only marked comparable when every run agreed for every seed.
 *
 * <p>Output is one tab-separated record per line:
 * {@code ordinal, registryName, seed, sequenceIsDeterministic (0|1), base64(scramble), base64(svg)}.
 * Base64 keeps SVG markup free of tabs and newlines without needing a JSON library.
 *
 * <p>Run as a single-file program on the JDK the library targets:
 * {@code java -cp <scrambles runtime classpath> GenerateExpectedScrambles.java}
 */
public final class GenerateExpectedScrambles {
    /** Fixed seeds; changing them only changes which states are compared. */
    private static final long[] SEEDS = {1L, 42L, 20_261_102L};

    private static final int RUNS_PER_SEED = 3;

    private GenerateExpectedScrambles() {
    }

    public static void main(String[] args) throws Exception {
        Base64.Encoder base64 = Base64.getEncoder();
        StringBuilder out = new StringBuilder();

        for (PuzzleRegistry entry : PuzzleRegistry.values()) {
            Puzzle puzzle = entry.getScrambler();
            String[] scrambles = new String[SEEDS.length];
            String[] svgs = new String[SEEDS.length];
            boolean sequenceIsDeterministic = true;

            for (int i = 0; i < SEEDS.length; i++) {
                scrambles[i] = puzzle.generateWcaScramble(new Random(SEEDS[i]));
                svgs[i] = draw(puzzle, scrambles[i]);

                for (int run = 1; run < RUNS_PER_SEED; run++) {
                    String again = puzzle.generateWcaScramble(new Random(SEEDS[i]));

                    if (!draw(puzzle, again).equals(svgs[i])) {
                        throw new IllegalStateException(
                            entry.name() + ": seed " + SEEDS[i] + " produced different states across runs");
                    }
                    sequenceIsDeterministic &= again.equals(scrambles[i]);
                }
            }

            for (int i = 0; i < SEEDS.length; i++) {
                out.append(entry.ordinal()).append('\t')
                    .append(entry.name()).append('\t')
                    .append(SEEDS[i]).append('\t')
                    .append(sequenceIsDeterministic ? '1' : '0').append('\t')
                    .append(base64.encodeToString(scrambles[i].getBytes(StandardCharsets.UTF_8))).append('\t')
                    .append(base64.encodeToString(svgs[i].getBytes(StandardCharsets.UTF_8))).append('\n');
            }
        }

        System.out.print(out);
    }

    private static String draw(Puzzle puzzle, String scramble) throws Exception {
        return puzzle.drawScramble(scramble, puzzle.parseColorScheme(null)).toString();
    }
}
