package org.worldcubeassociation.tnoodle.puzzle;

import java.util.random.RandomGenerator;

import org.timepedia.exporter.client.Export;
import org.worldcubeassociation.tnoodle.scrambles.AlgorithmBuilder;
import org.worldcubeassociation.tnoodle.scrambles.InvalidMoveException;
import org.worldcubeassociation.tnoodle.scrambles.PuzzleStateAndGenerator;

@Export
public class NoInspectionFourByFourCubePuzzle extends FourByFourCubePuzzle {
    public static PuzzleStateAndGenerator applyOrientation(
        CubePuzzle puzzle,
        CubeMove[] randomOrientation,
        PuzzleStateAndGenerator psag,
        boolean discardRedundantMoves
    ) {
        if (randomOrientation.length == 0) {
            // No reorientation required
            return psag;
        }

        // Append reorientation to scramble.
        try {
            AlgorithmBuilder ab = new AlgorithmBuilder(puzzle, AlgorithmBuilder.MergingMode.NO_MERGING);
            ab.appendAlgorithm(psag.generator);
            for (CubeMove cm : randomOrientation) {
                ab.appendMove(cm.toString());
            }

            psag = ab.getStateAndGenerator();
            return psag;
        } catch (InvalidMoveException e) {
            throw new RuntimeException(e);
        }
    }

    public NoInspectionFourByFourCubePuzzle() {
    }

    @Override
    public PuzzleStateAndGenerator generateRandomMoves(RandomGenerator r) {
        CubeMove[][] randomOrientationMoves = getRandomOrientationMoves(size - 1);
        CubeMove[] randomOrientation = randomOrientationMoves[r.nextInt(randomOrientationMoves.length)];
        PuzzleStateAndGenerator psag = super.generateRandomMoves(r);
        psag = applyOrientation(this, randomOrientation, psag, true);
        return psag;
    }

    @Override
    public String getShortName() {
        return "444ni";
    }

    @Override
    public String getLongName() {
        return "4x4x4 no inspection";
    }
}
