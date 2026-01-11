package org.worldcubeassociation.tnoodle.puzzle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import org.junit.jupiter.api.Test;
import org.worldcubeassociation.tnoodle.scrambles.AlgorithmBuilder;
import org.worldcubeassociation.tnoodle.scrambles.InvalidMoveException;
import org.worldcubeassociation.tnoodle.scrambles.Puzzle;

public class SquareOnePuzzleTest {
    @Test
    public void testMergingMode() throws InvalidMoveException {
        Puzzle sq1 = new SquareOnePuzzle();
        AlgorithmBuilder ab = new AlgorithmBuilder(sq1, AlgorithmBuilder.MergingMode.CANONICALIZE_MOVES);

        assertEquals(0, ab.getTotalCost());

        ab.appendMove("(1,0)");
        assertEquals(1, ab.getTotalCost());

        ab.appendMove("(2,0)");
        assertEquals(1, ab.getTotalCost());

        ab.appendMove("(0,-1)");
        assertEquals(1, ab.getTotalCost());

        ab.appendMove("/");
        assertEquals(2, ab.getTotalCost());

        ab.appendMove("/");
        assertEquals(1, ab.getTotalCost());

        Puzzle.PuzzleState state = ab.getState();

        String solution = state.solveIn(1);
        assertEquals("(-3,1)", solution);

        solution = state.solveIn(2);
        assertEquals("(-3,1)", solution);
    }

    @Test
    public void testSlashabilitySolutions() throws InvalidMoveException {
        Puzzle sq1 = new SquareOnePuzzle();

        // slashability is (-1,0) which then cancels into (-3,0)
        String cancelsWithSlashability = "(3,0) / (4,0)";

        String solution = solveScrambleStringIn(sq1, cancelsWithSlashability, 3);
        assertNotNull(solution);

        // slashability is (-1, 0) which trivially doesn't cancel the / move
        String doesntCancelSlashability = "(3,0) / (1,0)";

        solution = solveScrambleStringIn(sq1, doesntCancelSlashability, 3);
        assertNotNull(solution);
    }

    private String solveScrambleStringIn(Puzzle puzzle, String scramble, int n) throws InvalidMoveException {
        AlgorithmBuilder ab = new AlgorithmBuilder(puzzle, AlgorithmBuilder.MergingMode.CANONICALIZE_MOVES);
        ab.appendAlgorithm(scramble);

        return ab.getState().solveIn(n);
    }
}
