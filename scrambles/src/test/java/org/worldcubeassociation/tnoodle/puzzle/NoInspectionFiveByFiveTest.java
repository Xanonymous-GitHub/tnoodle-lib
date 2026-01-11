package org.worldcubeassociation.tnoodle.puzzle;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.worldcubeassociation.tnoodle.scrambles.AlgorithmBuilder;
import org.worldcubeassociation.tnoodle.scrambles.InvalidMoveException;
import org.worldcubeassociation.tnoodle.scrambles.PuzzleStateAndGenerator;

public class NoInspectionFiveByFiveTest {
    @Test
    public void testSomething() throws InvalidMoveException {
        CubePuzzle fives = new NoInspectionFiveByFiveCubePuzzle();

        CubePuzzle.CubeMove dummyMove = fives.new CubeMove(CubePuzzle.Face.U, 1, 3);
        CubePuzzle.CubeMove[] reorient = new CubePuzzle.CubeMove[] { dummyMove };

        assertEquals("4Uw", reorient[0].toString());

        AlgorithmBuilder ab = new AlgorithmBuilder(fives, AlgorithmBuilder.MergingMode.NO_MERGING);
        ab.appendAlgorithm("F R");

        PuzzleStateAndGenerator psag1 = ab.getStateAndGenerator();
        PuzzleStateAndGenerator psag2 = NoInspectionFiveByFiveCubePuzzle.applyOrientation(fives, reorient, psag1, true);
        //The scramble (F R) and the reorient (4Uw) don't conflict,
        //so the resulting scramble should be "F R 4Uw"
        assertEquals("F R 4Uw", psag2.generator);

        ab = new AlgorithmBuilder(fives, AlgorithmBuilder.MergingMode.NO_MERGING);
        ab.appendAlgorithm("F D");

        psag1 = ab.getStateAndGenerator();
        psag2 = NoInspectionFiveByFiveCubePuzzle.applyOrientation(fives, reorient, psag1, true);
        //The scramble (F D) and the reorient (4Uw) are redundant.
        //The problematic D turn should be removed, and the resulting
        //scramble should be "F 4Uw"
        assertEquals("F 4Uw", psag2.generator);

        ab = new AlgorithmBuilder(fives, AlgorithmBuilder.MergingMode.NO_MERGING);
        ab.appendAlgorithm("D U D U");

        psag1 = ab.getStateAndGenerator();
        psag2 = NoInspectionFiveByFiveCubePuzzle.applyOrientation(fives, reorient, psag1, true);
        //The scramble (D U D U) and the reorient (4Uw) are redundant.
        //The problematic D turns should be removed, and the resulting
        //scramble should be "U U 4Uw"
        assertEquals("U U 4Uw", psag2.generator);
    }
}
