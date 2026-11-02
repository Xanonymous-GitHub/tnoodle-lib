import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Random;

import org.worldcubeassociation.tnoodle.puzzle.ThreeByThreeCubePuzzle;
import org.worldcubeassociation.tnoodle.scrambles.Puzzle;
import org.worldcubeassociation.tnoodle.scrambles.PuzzleRegistry;

/**
 * Writes the JVM reference output that the XCFramework smoke tests compare against.
 *
 * <p>For every {@link PuzzleRegistry} entry and every seed, this mirrors what {@code TNoodle.m}
 * does on Apple platforms: {@code generateWcaScramble(new Random(seed))} followed by
 * {@code drawScramble(scramble, parseColorScheme(null))}.
 *
 * <p>A seed always determines the scrambled <em>state</em>, so the SVG of that state must contain
 * exactly the same elements on every platform. Their paint order may differ between processes
 * (Megaminx iterates a {@code HashMap} keyed by an enum), so consumers compare elements in any
 * order. A seed does not always determine the <em>move sequence</em>, for two reasons in the
 * official solvers:
 * <ul>
 *   <li>Pyraminx and Skewb pick among equally short solutions with their own unseeded
 *       {@code Random}. Each puzzle is generated {@value #RUNS_PER_SEED} times per seed to catch
 *       this.</li>
 *   <li>The 3x3x3 family ({@link ThreeByThreeCubePuzzle} and its subclasses) searches with
 *       min2phase's {@code SearchWCA}, which keeps looking for shorter solutions for a fixed
 *       wall-clock time. The result depends on CPU speed, so it can differ on another machine
 *       or platform even though it never varies between runs on one machine.</li>
 * </ul>
 * The move sequence is only marked comparable when neither applies.
 *
 * <p>Output is one tab-separated record per line:
 * {@code ordinal, registryName, seed, sequenceIsComparable (0|1), base64(scramble), base64(svg)}.
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
            // Wall-clock bounded: runs on this machine agree, yet another platform may not.
            boolean sequenceIsComparable = !(puzzle instanceof ThreeByThreeCubePuzzle);

            for (int i = 0; i < SEEDS.length; i++) {
                scrambles[i] = puzzle.generateWcaScramble(new Random(SEEDS[i]));
                svgs[i] = draw(puzzle, scrambles[i]);

                for (int run = 1; run < RUNS_PER_SEED; run++) {
                    String again = puzzle.generateWcaScramble(new Random(SEEDS[i]));

                    if (!draw(puzzle, again).equals(svgs[i])) {
                        throw new IllegalStateException(
                            entry.name() + ": seed " + SEEDS[i] + " produced different states across runs");
                    }
                    sequenceIsComparable &= again.equals(scrambles[i]);
                }
            }

            for (int i = 0; i < SEEDS.length; i++) {
                out.append(entry.ordinal()).append('\t')
                    .append(entry.name()).append('\t')
                    .append(SEEDS[i]).append('\t')
                    .append(sequenceIsComparable ? '1' : '0').append('\t')
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
