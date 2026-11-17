package org.worldcubeassociation.tnoodle.puzzle;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.timepedia.exporter.client.Export;
import org.worldcubeassociation.tnoodle.puzzle.TwoByTwoSolver.TwoByTwoState;
import org.worldcubeassociation.tnoodle.scrambles.Puzzle;
import org.worldcubeassociation.tnoodle.svglite.Color;
import org.worldcubeassociation.tnoodle.svglite.Dimension;
import org.worldcubeassociation.tnoodle.svglite.Rectangle;
import org.worldcubeassociation.tnoodle.svglite.Svg;

@Export
public class CubePuzzle extends Puzzle {

    private static final String[] DIR_TO_STR = new String[] { null, "", "2", "'" };
    private static final Map<Face, String> faceRotationsByName = new HashMap<>();
    private static final int gap = 2;
    private static final int cubieSize = 10;
    private static final int[] DEFAULT_LENGTHS = { 0, 0, 25, 25, 40, 60, 80, 100, 120, 140, 160, 180 };
    private static final Map<String, Color> defaultColorScheme = new HashMap<>();

    static {
        faceRotationsByName.put(Face.R, "x");
        faceRotationsByName.put(Face.U, "y");
        faceRotationsByName.put(Face.F, "z");
    }

    static {
        defaultColorScheme.put("B", Color.BLUE);
        defaultColorScheme.put("D", Color.YELLOW);
        defaultColorScheme.put("F", Color.GREEN);
        defaultColorScheme.put("L", Color.ORANGE);
        defaultColorScheme.put("R", Color.RED);
        defaultColorScheme.put("U", Color.WHITE);
    }

    protected final int size;

    public CubePuzzle(int size) {
        assert size >= 0 && size < DEFAULT_LENGTHS.length : "Invalid cube size";
        this.size = size;
    }

    // The image is one flat array: face f, row r, column c is at (f * size + r) * size + c.
    private static int at(int size, int f, int r, int c) {
        return (f * size + r) * size + c;
    }

    private static void swap(int[] image, int i1, int i2, int i3, int i4, int dir) {
        if (dir == 1) {
            int temp = image[i1];
            image[i1] = image[i2];
            image[i2] = image[i3];
            image[i3] = image[i4];
            image[i4] = temp;
        } else if (dir == 2) {
            int temp = image[i1];
            image[i1] = image[i3];
            image[i3] = temp;
            temp = image[i2];
            image[i2] = image[i4];
            image[i4] = temp;
        } else if (dir == 3) {
            int temp = image[i4];
            image[i4] = image[i3];
            image[i3] = image[i2];
            image[i2] = image[i1];
            image[i1] = temp;
        } else {
            assert false;
        }
    }

    private static void slice(Face face, int slice, int dir, int size, int[] image) {
        assert slice >= 0 && slice < size;

        Face sface = face;
        int sslice = slice;
        int sdir = dir;

        if (face != Face.L && face != Face.D && face != Face.B) {
            sface = face.oppositeFace();
            sslice = size - 1 - slice;
            sdir = 4 - dir;
        }
        int u = Face.U.ordinal(), b = Face.B.ordinal(), d = Face.D.ordinal();
        int f = Face.F.ordinal(), l = Face.L.ordinal(), r = Face.R.ordinal();
        for (int j = 0; j < size; j++) {
            if (sface == Face.L) {
                swap(
                    image,
                    at(size, u, j, sslice),
                    at(size, b, size - 1 - j, size - 1 - sslice),
                    at(size, d, j, sslice),
                    at(size, f, j, sslice),
                    sdir
                );
            } else if (sface == Face.D) {
                swap(
                    image,
                    at(size, l, size - 1 - sslice, j),
                    at(size, b, size - 1 - sslice, j),
                    at(size, r, size - 1 - sslice, j),
                    at(size, f, size - 1 - sslice, j),
                    sdir
                );
            } else if (sface == Face.B) {
                swap(
                    image,
                    at(size, u, sslice, j),
                    at(size, r, j, size - 1 - sslice),
                    at(size, d, size - 1 - sslice, size - 1 - j),
                    at(size, l, size - 1 - j, sslice),
                    sdir
                );
            } else {
                assert false;
            }
        }
        if (slice == 0 || slice == size - 1) {
            int face2;
            if (slice == 0) {
                face2 = face.ordinal();
                sdir = 4 - dir;
            } else if (slice == size - 1) {
                face2 = face.oppositeFace().ordinal();
                sdir = dir;
            } else {
                assert false;
                return;
            }
            for (int j = 0; j < (size + 1) / 2; j++) {
                for (int k = 0; k < size / 2; k++) {
                    swap(
                        image,
                        at(size, face2, j, k),
                        at(size, face2, k, size - 1 - j),
                        at(size, face2, size - 1 - j, size - 1 - k),
                        at(size, face2, size - 1 - k, j),
                        sdir
                    );
                }
            }
        }
    }

    private static int getCubeViewWidth(int cubie, int gap, int size) {
        return (size * cubie + gap) * 4 + gap;
    }

    private static int getCubeViewHeight(int cubie, int gap, int size) {
        return (size * cubie + gap) * 3 + gap;
    }

    private static Dimension getImageSize(int gap, int unitSize, int size) {
        return new Dimension(getCubeViewWidth(unitSize, gap, size), getCubeViewHeight(unitSize, gap, size));
    }

    protected static int[][] getStickersByPiece(int[] img, int size) {
        int s = size - 1;
        return new int[][] {
            { img[at(size, Face.U.ordinal(), s, s)], img[at(size, Face.R.ordinal(), 0, 0)], img[at(size, Face.F.ordinal(), 0, s)] },
            { img[at(size, Face.U.ordinal(), s, 0)], img[at(size, Face.F.ordinal(), 0, 0)], img[at(size, Face.L.ordinal(), 0, s)] },
            { img[at(size, Face.U.ordinal(), 0, s)], img[at(size, Face.B.ordinal(), 0, 0)], img[at(size, Face.R.ordinal(), 0, s)] },
            { img[at(size, Face.U.ordinal(), 0, 0)], img[at(size, Face.L.ordinal(), 0, 0)], img[at(size, Face.B.ordinal(), 0, s)] },

            { img[at(size, Face.D.ordinal(), 0, s)], img[at(size, Face.F.ordinal(), s, s)], img[at(size, Face.R.ordinal(), s, 0)] },
            { img[at(size, Face.D.ordinal(), 0, 0)], img[at(size, Face.L.ordinal(), s, s)], img[at(size, Face.F.ordinal(), s, 0)] },
            { img[at(size, Face.D.ordinal(), s, s)], img[at(size, Face.R.ordinal(), s, s)], img[at(size, Face.B.ordinal(), s, 0)] },
            { img[at(size, Face.D.ordinal(), s, 0)], img[at(size, Face.B.ordinal(), s, s)], img[at(size, Face.L.ordinal(), s, 0)] }
        };
    }

    protected CubeMove[][] getRandomOrientationMoves(int thickness) {
        CubeMove[] randomUFaceMoves = new CubeMove[] {
            null,
            new CubeMove(Face.R, 1, thickness),
            new CubeMove(Face.R, 2, thickness),
            new CubeMove(Face.R, 3, thickness),
            new CubeMove(Face.F, 1, thickness),
            new CubeMove(Face.F, 3, thickness)
        };
        CubeMove[] randomFFaceMoves = new CubeMove[] {
            null,
            new CubeMove(Face.U, 1, thickness),
            new CubeMove(Face.U, 2, thickness),
            new CubeMove(Face.U, 3, thickness)
        };
        CubeMove[][] randomOrientationMoves = new CubeMove[randomUFaceMoves.length * randomFFaceMoves.length][];
        int i = 0;
        for (CubeMove randomUFaceMove : randomUFaceMoves) {
            for (CubeMove randomFFaceMove : randomFFaceMoves) {
                List<CubeMove> moves = new ArrayList<>();
                if (randomUFaceMove != null) {
                    moves.add(randomUFaceMove);
                }
                if (randomFFaceMove != null) {
                    moves.add(randomFFaceMove);
                }
                CubeMove[] movesArr = moves.toArray(new CubeMove[0]);
                randomOrientationMoves[i++] = movesArr;
            }
        }
        return randomOrientationMoves;
    }

    @Override
    public String getLongName() {
        return size + "x" + size + "x" + size;
    }

    @Override
    public String getShortName() {
        return size + "" + size + size;
    }

    @Override
    public Map<String, Color> getDefaultColorScheme() {
        return new HashMap<>(defaultColorScheme);
    }

    @Override
    public Dimension getPreferredSize() {
        return getImageSize(gap, cubieSize, size);
    }

    private void drawCube(Svg g, int[] state, int gap, int cubieSize, Map<String, Color> colorScheme) {
        paintCubeFace(g, gap, 2 * gap + size * cubieSize, size, cubieSize, state, Face.L.ordinal(), colorScheme);
        paintCubeFace(g, 2 * gap + size * cubieSize, 3 * gap + 2 * size * cubieSize, size, cubieSize, state, Face.D.ordinal(), colorScheme);
        paintCubeFace(g, 4 * gap + 3 * size * cubieSize, 2 * gap + size * cubieSize, size, cubieSize, state, Face.B.ordinal(), colorScheme);
        paintCubeFace(g, 3 * gap + 2 * size * cubieSize, 2 * gap + size * cubieSize, size, cubieSize, state, Face.R.ordinal(), colorScheme);
        paintCubeFace(g, 2 * gap + size * cubieSize, gap, size, cubieSize, state, Face.U.ordinal(), colorScheme);
        paintCubeFace(g, 2 * gap + size * cubieSize, 2 * gap + size * cubieSize, size, cubieSize, state, Face.F.ordinal(), colorScheme);
    }

    private void paintCubeFace(Svg g, int x, int y, int size, int cubieSize, int[] state, int face, Map<String, Color> colorScheme) {
        for (int row = 0; row < size; row++) {
            for (int col = 0; col < size; col++) {
                int tempx = x + col * cubieSize;
                int tempy = y + row * cubieSize;
                Rectangle rect = new Rectangle(tempx, tempy, cubieSize, cubieSize);
                rect.setFill(colorScheme.get(Face.values()[state[at(size, face, row, col)]].toString()));
                rect.setStroke(Color.BLACK);
                g.appendChild(rect);
            }
        }
    }

    @Override
    public CubeState getSolvedState() {
        return new CubeState();
    }

    @Override
    protected int getRandomMoveCount() {
        return DEFAULT_LENGTHS[size];
    }

    private void spinCube(int[] image, Face face, int dir) {
        for (int slice = 0; slice < size; slice++) {
            slice(face, slice, dir, size, image);
        }
    }

    private int[] normalize(int[] image) {
        image = image.clone();

        int spins = 0;
        while (!isNormalized(image)) {
            assert spins < 2;
            int[][] stickersByPiece = getStickersByPiece(image, size);

            int goal = 0;
            goal |= 1 << Face.B.ordinal();
            goal |= 1 << Face.L.ordinal();
            goal |= 1 << Face.D.ordinal();
            int idx = -1;
            for (int i = 0; i < stickersByPiece.length; i++) {
                int t = 0;
                for (int j = 0; j < stickersByPiece[i].length; j++) {
                    t |= 1 << stickersByPiece[i][j];
                }
                if (t == goal) {
                    idx = i;
                    break;
                }
            }
            assert idx >= 0;
            Face f = null;
            int dir = 1;
            if (stickersByPiece[idx][0] == Face.D.ordinal()) {
                if (idx < 4) {
                    // on U
                    f = Face.F;
                    dir = 2;
                } else {
                    // on D
                    f = Face.U;
                    switch (idx) {
                        case 4:
                            dir = 2;
                            break;
                        case 5:
                            dir = 1;
                            break;
                        case 6:
                            dir = 3;
                            break;
                        default:
                            assert false;
                    }
                }
            } else if (stickersByPiece[idx][1] == Face.D.ordinal()) {
                switch (idx) {
                    case 0:
                    case 6:
                        f = Face.F;
                        break; // on R
                    case 1:
                    case 4:
                        f = Face.L;
                        break; // on F
                    case 2:
                    case 7:
                        f = Face.R;
                        break; // on B
                    case 3:
                    case 5:
                        f = Face.B;
                        break; // on L
                    default:
                        assert false;
                }
            } else {
                switch (idx) {
                    case 2:
                    case 4:
                        f = Face.F;
                        break; // on R
                    case 0:
                    case 5:
                        f = Face.L;
                        break; // on F
                    case 3:
                    case 6:
                        f = Face.R;
                        break; // on B
                    case 1:
                    case 7:
                        f = Face.B;
                        break; // on L
                    default:
                        assert false;
                }
            }
            spinCube(image, f, dir);
            spins++;
        }

        return image;
    }

    private boolean isNormalized(int[] image) {
        // A CubeState is normalized if the BLD piece is solved
        return image[at(size, Face.B.ordinal(), size - 1, size - 1)] == Face.B.ordinal() &&
               image[at(size, Face.L.ordinal(), size - 1, 0)] == Face.L.ordinal() &&
               image[at(size, Face.D.ordinal(), size - 1, 0)] == Face.D.ordinal();
    }

    public enum Face {
        R,
        U,
        F,
        L,
        D,
        B;

        public Face oppositeFace() {
            return values()[(ordinal() + 3) % 6];
        }
    }

    public class CubeMove {
        Face face;
        int dir;
        int innerSlice, outerSlice;

        public CubeMove(Face face, int dir) {
            this(face, dir, 0);
        }

        public CubeMove(Face face, int dir, int innerSlice) {
            this(face, dir, innerSlice, 0);
        }

        public CubeMove(Face face, int dir, int innerSlice, int outerSlice) {
            this.face = face;
            this.dir = dir;
            this.innerSlice = innerSlice;
            this.outerSlice = outerSlice;
            // We haven't come up with names for moves where outerSlice != 0
            assert outerSlice == 0;
        }

        public String toString() {
            String f = face.toString();
            String move;
            if (innerSlice == 0) {
                move = f;
            } else if (innerSlice == 1) {
                move = f + "w";
            } else if (innerSlice == size - 1) {
                // Turning all the slices is a rotation
                String rotationName = faceRotationsByName.get(face);
                if (rotationName == null) {
                    // Not all rotations are actually named.
                    return null;
                }
                move = rotationName;
            } else {
                move = (innerSlice + 1) + f + "w";
            }
            move += DIR_TO_STR[dir];

            return move;
        }
    }

    public class CubeState extends PuzzleState {
        private final int[] image;
        private CubeState normalizedState = null;

        public CubeState() {
            int faceSize = size * size;
            image = new int[6 * faceSize];
            for (int face = 0; face < 6; face++) {
                Arrays.fill(image, face * faceSize, (face + 1) * faceSize, face);
            }
            normalizedState = this;
        }

        public CubeState(int[] image) {
            this.image = image;
        }

        public boolean isNormalized() {
            return CubePuzzle.this.isNormalized(image);
        }

        public CubeState getNormalized() {
            if (normalizedState == null) {
                int[] normalizedImage = normalize(image);
                normalizedState = new CubeState(normalizedImage);
            }
            return normalizedState;
        }

        public TwoByTwoState toTwoByTwoState() {
            TwoByTwoState state = new TwoByTwoState();

            int[][] stickersByPiece = getStickersByPiece(image, size);

            // Here's a clever color value assigning system that gives each piece
            // a unique id just by summing up the values of its stickers.
            //
            //            +----------+
            //            |*3*    *2*|
            //            |   U (0)  |
            //            |*1*    *0*|
            // +----------+----------+----------+----------+
            // | 3      1 | 1      0 | 0      2 | 2      3 |
            // |   L (1)  |   F (0)  |   R (0)  |   B (2)  |
            // | 7      5 | 5      4 | 4      6 | 6      7 |
            // +----------+----------+----------+----------+
            //            |*5*    *4*|
            //            |   D (4)  |
            //            |*7*    *6*|
            //            +----------+
            //

            int dColor = stickersByPiece[7][0];
            int bColor = stickersByPiece[7][1];
            int lColor = stickersByPiece[7][2];

            int uColor = Face.values()[dColor].oppositeFace().ordinal();
            int fColor = Face.values()[bColor].oppositeFace().ordinal();
            int rColor = Face.values()[lColor].oppositeFace().ordinal();

            int[] colorToVal = new int[8];
            colorToVal[uColor] = 0;
            colorToVal[fColor] = 0;
            colorToVal[rColor] = 0;
            colorToVal[lColor] = 1;
            colorToVal[bColor] = 2;
            colorToVal[dColor] = 4;

            int[] pieces = new int[7];
            for (int i = 0; i < pieces.length; i++) {
                int[] stickers = stickersByPiece[i];
                int pieceVal = colorToVal[stickers[0]] + colorToVal[stickers[1]] + colorToVal[stickers[2]];

                int clockwiseTurnsToGetToPrimaryColor = 0;
                while (stickers[clockwiseTurnsToGetToPrimaryColor] != uColor && stickers[clockwiseTurnsToGetToPrimaryColor] != dColor) {
                    clockwiseTurnsToGetToPrimaryColor++;
                    assert clockwiseTurnsToGetToPrimaryColor < 3;
                }
                int piece = (clockwiseTurnsToGetToPrimaryColor << 3) + pieceVal;
                pieces[i] = piece;
            }

            state.permutation = TwoByTwoSolver.packPerm(pieces);
            state.orientation = TwoByTwoSolver.packOrient(pieces);
            return state;
        }

        /**
         * Returns a string representing the colors of the cube.
         * Looking at the face, each sticker is described in the reading order,
         * that is, from left to right, from up to bottom.
         * Faces order follow U, R, F, D, L, B.
         * @return A string, not spaced, containing the color of each sticker.
         * This color refers to the solved state. If white is the color of the U face when solved,
         * then every white sticker is described as U.
         */
        public String toFaceCube() {
            assert size == 3;
            StringBuilder state = new StringBuilder();
            for (char f : "URFDLB".toCharArray()) {
                Face face = Face.valueOf("" + f);
                int first = at(size, face.ordinal(), 0, 0);
                for (int i = first; i < first + size * size; i++) {
                    state.append(Face.values()[image[i]].toString());
                }
            }
            return state.toString();
        }

        @Override
        public Map<String, CubeState> getSuccessorsByName() {
            return getSuccessorsWithinSlice(size - 1, true);
        }

        @Override
        public Map<String, CubeState> getScrambleSuccessors() {
            return getSuccessorsWithinSlice((size / 2) - 1, false);
        }

        @Override
        public Map<? extends PuzzleState, String> getCanonicalMovesByState() {
            Map<PuzzleState, String> reversed = new HashMap<>();

            for (Map.Entry<String, ? extends PuzzleState> entry : getScrambleSuccessors().entrySet()) {
                reversed.put(entry.getValue(), entry.getKey());
            }

            return reversed;
        }

        private Map<String, CubeState> getSuccessorsWithinSlice(int maxSlice, boolean includeRedundant) {
            Map<String, CubeState> successors = new LinkedHashMap<>();
            for (int innerSlice = 0; innerSlice <= maxSlice; innerSlice++) {
                for (Face face : Face.values()) {
                    boolean halfOfEvenCube = size % 2 == 0 && (innerSlice == (size / 2) - 1);
                    if (!includeRedundant && face.ordinal() >= 3 && halfOfEvenCube) {
                        // Skip turning the other halves of even sized cubes
                        continue;
                    }
                    int outerSlice = 0;
                    for (int dir = 1; dir <= 3; dir++) {
                        CubeMove move = new CubeMove(face, dir, innerSlice, outerSlice);
                        String moveStr = move.toString();
                        if (moveStr == null) {
                            // Skip unnamed rotations.
                            continue;
                        }

                        int[] imageCopy = image.clone();
                        for (int slice = outerSlice; slice <= innerSlice; slice++) {
                            slice(face, slice, dir, size, imageCopy);
                        }
                        successors.put(moveStr, new CubeState(imageCopy));
                    }
                }
            }

            return successors;
        }

        @Override
        public boolean equals(Object other) {
            return Arrays.equals(image, ((CubeState) other).image);
        }

        // Same value as Arrays.deepHashCode on the former int[6][size][size] image, so
        // hash-based collections keep their iteration order and scrambles stay the same.
        @Override
        public int hashCode() {
            int cube = 1;
            int i = 0;
            for (int face = 0; face < 6; face++) {
                int faceHash = 1;
                for (int row = 0; row < size; row++) {
                    int rowHash = 1;
                    for (int col = 0; col < size; col++) {
                        rowHash = 31 * rowHash + image[i++];
                    }
                    faceHash = 31 * faceHash + rowHash;
                }
                cube = 31 * cube + faceHash;
            }
            return cube;
        }

        protected Svg drawScramble(Map<String, Color> colorScheme) {
            Svg svg = new Svg(getPreferredSize());
            drawCube(svg, image, gap, cubieSize, colorScheme);
            return svg;
        }
    }

}
