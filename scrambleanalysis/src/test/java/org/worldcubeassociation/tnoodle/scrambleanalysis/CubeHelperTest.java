package org.worldcubeassociation.tnoodle.scrambleanalysis;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.logging.Logger;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.worldcubeassociation.tnoodle.puzzle.CubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.ThreeByThreeCubePuzzle;
import org.worldcubeassociation.tnoodle.scrambles.InvalidScrambleException;

public class CubeHelperTest {

    ThreeByThreeCubePuzzle cube = new ThreeByThreeCubePuzzle();
    Logger logger = Logger.getLogger(CubeHelperTest.class.getName());

    @Test
    public void orientationTest() throws InvalidScrambleException, RepresentationException {
        int n = 1;

        // The number of misoriented edge must be even, corner orientation sum must be a
        // multiple of 3.
        for (int i = 0; i < n; i++) {
            String scramble = cube.generateScramble();
            CubePuzzle.CubeState state = (CubePuzzle.CubeState) cube.getSolvedState().applyAlgorithm(scramble);
            String representation = state.toFaceCube();

            int misorientedEdges = CubeHelper.countMisorientedEdges(representation);
            int cornerSum = CubeHelper.cornerOrientationSum(representation);

            logger.info("Scramble: " + scramble);
            logger.info("Misoriented edges: " + misorientedEdges);
            logger.info("Corner sum: " + cornerSum);
            logger.info("Parity: " + CubeHelper.hasParity(representation));

            assertEquals(0, misorientedEdges % 2);
            assertEquals(0, cornerSum % 3);
        }
    }

    @Test
    public void hasParityTest() throws InvalidScrambleException {
        String scramble = "U";
        Assertions.assertTrue(CubeHelper.hasParity(getRepresentation(scramble)));

        scramble = "U'";
        Assertions.assertTrue(CubeHelper.hasParity(getRepresentation(scramble)));

        scramble = "U2";
        Assertions.assertFalse(CubeHelper.hasParity(getRepresentation(scramble)));

        String yPerm = "F R U' R' U' R U R' F' R U R' U' R' F R F'";
        Assertions.assertTrue(CubeHelper.hasParity(getRepresentation(yPerm)));

        String uPerm = "R2 U' R' U' R U R U R U' R";
        Assertions.assertFalse(CubeHelper.hasParity(getRepresentation(uPerm)));
    }

    @Test
    public void countMisorientedEdgesTest() throws InvalidScrambleException, RepresentationException {
        String scramble1 = "F";
        String scramble2 = "F' B";
        String scramble3 = "F U F";

        CubePuzzle.CubeState state1 = (CubePuzzle.CubeState) cube.getSolvedState().applyAlgorithm(scramble1);
        String representation1 = state1.toFaceCube();
        int result1 = CubeHelper.countMisorientedEdges(representation1);

        CubePuzzle.CubeState state2 = (CubePuzzle.CubeState) cube.getSolvedState().applyAlgorithm(scramble2);
        String representation2 = state2.toFaceCube();
        int result2 = CubeHelper.countMisorientedEdges(representation2);

        CubePuzzle.CubeState state3 = (CubePuzzle.CubeState) cube.getSolvedState().applyAlgorithm(scramble3);
        String representation3 = state3.toFaceCube();
        int result3 = CubeHelper.countMisorientedEdges(representation3);

        assertEquals(4, result1);
        assertEquals(8, result2);
        assertEquals(2, result3);

        Assertions.assertEquals(
            CubeHelper.countMisorientedEdges(representation1),
            CubeHelper.countMisorientedEdges(state1)
        );
        Assertions.assertEquals(
            CubeHelper.countMisorientedEdges(representation2),
            CubeHelper.countMisorientedEdges(state2)
        );
        Assertions.assertEquals(
            CubeHelper.countMisorientedEdges(representation3),
            CubeHelper.countMisorientedEdges(state3)
        );
    }

    @Test
    public void isOrientedEdgeTest() throws InvalidScrambleException, RepresentationException {
        String scramble = "F B'";
        String representation = getRepresentation(scramble);

        Assertions.assertTrue(CubeHelper.isOrientedEdge(representation, 1));
        Assertions.assertTrue(CubeHelper.isOrientedEdge(representation, 2));
        Assertions.assertTrue(CubeHelper.isOrientedEdge(representation, 5));
        Assertions.assertTrue(CubeHelper.isOrientedEdge(representation, 6));

        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 0));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 3));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 4));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 7));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 8));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 9));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 10));
        Assertions.assertFalse(CubeHelper.isOrientedEdge(representation, 11));
    }

    @Test
    public void getFinalPositionTest() throws InvalidScrambleException, RepresentationException {
        String scramble1 = "U2";
        String representation1 = getRepresentation(scramble1);

        String scramble2 = "R U R' U R U2 R'";
        String representation2 = getRepresentation(scramble2);

        Assertions.assertEquals(3, CubeHelper.getFinalPositionOfEdge(representation1, 0));
        Assertions.assertEquals(1, CubeHelper.getFinalPositionOfEdge(representation2, 0));

        Assertions.assertEquals(3, CubeHelper.getFinalPositionOfCorner(representation1, 0));
        Assertions.assertEquals(3, CubeHelper.getFinalPositionOfCorner(representation2, 0));

        Assertions.assertEquals(7, CubeHelper.getFinalPositionOfCorner(getRepresentation("R"), 1));
        Assertions.assertEquals(3, CubeHelper.getFinalPositionOfCorner(getRepresentation("R'"), 1));
    }

    private String getRepresentation(String scramble) throws InvalidScrambleException {
        CubePuzzle.CubeState state = (CubePuzzle.CubeState) cube.getSolvedState().applyAlgorithm(scramble);
        return state.toFaceCube();
    }
}
