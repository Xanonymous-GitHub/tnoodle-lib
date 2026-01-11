package org.worldcubeassociation.tnoodle.scrambles;

import org.worldcubeassociation.tnoodle.puzzle.ClockPuzzle;
import org.worldcubeassociation.tnoodle.puzzle.CubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.FourByFourCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.FourByFourRandomTurnsCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.MegaminxPuzzle;
import org.worldcubeassociation.tnoodle.puzzle.NoInspectionFiveByFiveCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.NoInspectionFourByFourCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.NoInspectionThreeByThreeCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.PyraminxPuzzle;
import org.worldcubeassociation.tnoodle.puzzle.SkewbPuzzle;
import org.worldcubeassociation.tnoodle.puzzle.SquareOnePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.ThreeByThreeCubeFewestMovesPuzzle;
import org.worldcubeassociation.tnoodle.puzzle.ThreeByThreeCubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.TwoByTwoCubePuzzle;

public enum PuzzleRegistry {
    TWO(TwoByTwoCubePuzzle.class),
    THREE(ThreeByThreeCubePuzzle.class),
    FOUR(FourByFourCubePuzzle.class),
    FOUR_FAST(FourByFourRandomTurnsCubePuzzle.class),
    FIVE(CubePuzzle.class, 5),
    SIX(CubePuzzle.class, 6),
    SEVEN(CubePuzzle.class, 7),
    THREE_NI(NoInspectionThreeByThreeCubePuzzle.class),
    FOUR_NI(NoInspectionFourByFourCubePuzzle.class),
    FIVE_NI(NoInspectionFiveByFiveCubePuzzle.class),
    THREE_FM(ThreeByThreeCubeFewestMovesPuzzle.class),
    PYRA(PyraminxPuzzle.class),
    SQ1(SquareOnePuzzle.class),
    MEGA(MegaminxPuzzle.class),
    CLOCK(ClockPuzzle.class),
    SKEWB(SkewbPuzzle.class);

    private final LazySupplier<? extends Puzzle> puzzleSupplier;

    <T extends Puzzle> PuzzleRegistry(Class<T> suppliyingClass, Object... ctorArgs) {
        this.puzzleSupplier = new LazySupplier<>(suppliyingClass, ctorArgs);
    }

    public Puzzle getScrambler() {
        return this.puzzleSupplier.getInstance();
    }

    // WORD OF ADVICE: The puzzles that use local scrambling mechanisms
    // should not take long to boot anyways because their computation-heavy
    // code is wrapped in ThreadLocal objects that are only executed on-demand

    public String getKey() {
        return this.getScrambler().getShortName();
    }

    public String getDescription() {
        return this.getScrambler().getLongName();
    }
}
