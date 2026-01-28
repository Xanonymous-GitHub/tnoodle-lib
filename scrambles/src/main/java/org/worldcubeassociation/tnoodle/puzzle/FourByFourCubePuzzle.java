package org.worldcubeassociation.tnoodle.puzzle;

import java.util.Random;

import org.timepedia.exporter.client.Export;
import org.worldcubeassociation.tnoodle.scrambles.AlgorithmBuilder;
import org.worldcubeassociation.tnoodle.scrambles.AlgorithmBuilder.MergingMode;
import org.worldcubeassociation.tnoodle.scrambles.InvalidMoveException;
import org.worldcubeassociation.tnoodle.scrambles.InvalidScrambleException;
import org.worldcubeassociation.tnoodle.scrambles.PuzzleStateAndGenerator;

import cs.threephase.Edge3;
import cs.threephase.Search;

@Export
public class FourByFourCubePuzzle extends CubePuzzle {
    private static final ThreadLocal<Search> THREE_PHASE_SEARCHER = ThreadLocal.withInitial(Search::new);

    public FourByFourCubePuzzle() {
        super(4);
    }

    public double getInitializationStatus() {
        return Edge3.initStatus();
    }

    @Override
    public PuzzleStateAndGenerator generateRandomMoves(Random r) {
        final Search search = THREE_PHASE_SEARCHER.get();
        final String scramble = search.randomState(r);
        final AlgorithmBuilder ab = new AlgorithmBuilder(this, MergingMode.CANONICALIZE_MOVES);
        try {
            ab.appendAlgorithm(scramble);
        } catch (InvalidMoveException e) {
            throw new RuntimeException("threephase produced an invalid scramble: " + scramble, new InvalidScrambleException(scramble, e));
        }
        return ab.getStateAndGenerator();
    }
}
