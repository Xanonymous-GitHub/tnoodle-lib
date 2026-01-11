package org.worldcubeassociation.tnoodle.scrambleanalysis;

import java.util.List;

import org.worldcubeassociation.tnoodle.puzzle.CubePuzzle;
import org.worldcubeassociation.tnoodle.puzzle.ThreeByThreeCubePuzzle;
import org.worldcubeassociation.tnoodle.scrambles.InvalidScrambleException;

public class App {

    static void main(String[] args)
    throws InvalidScrambleException, RepresentationException {

        // to test your set of scrambles
        // ArrayList<String> scrambles = ScrambleProvider.getScrambles(fileName);
        // boolean passed = testScrambles(scrambles);

        // Main test
        int numberOfScrambles = 6500;
        CubePuzzle puzzle = new ThreeByThreeCubePuzzle();

        List<String> scrambles = ScrambleProvider.generateWcaScrambles(puzzle, numberOfScrambles);
        List<CubePuzzle.CubeState> representations = ScrambleProvider.convertToCubeStates(scrambles);

        boolean passed = CubeTest.testScrambles(representations);
        System.out.println("\nMain test passed? " + passed);

    }
}
