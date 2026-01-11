package cs.threephase;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Tools {
    static Random r = new Random();
    private static final Logger logger = LoggerFactory.getLogger(Tools.class);

    public static String randomCube() {
        return randomCube(r);
    }

    public static String randomCube(Random r) {
        FullCube c = new FullCube(r);
        byte[] f = new byte[96];
        c.toFacelet(f);
        StringBuilder sb = new StringBuilder();
        for (byte i : f) {
            sb.append("URFDLB".charAt(i));
        }
        return sb.toString();
    }

    public synchronized static void initFrom(DataInput in) throws IOException {
        if (Search.inited) {
            return;
        }

        logger.info("Initialize Center1 Solver...");

        Center1.initSym();
        Center1.initSym2Raw();
        read(Center1.ctsmv, in);
        Center1.createPrun();

        logger.info("Initialize Center2 Solver...");

        Center2.init();

        logger.info("Initialize Center3 Solver...");

        Center3.init();

        logger.info("Initialize Edge3 Solver...");

        Edge3.initMvrot();
        Edge3.initRaw2Sym();
        read(Edge3.eprun, in);
        Edge3.done = Edge3.N_EPRUN;

        logger.info("OK");

        Search.inited = true;
    }

    public synchronized static void saveTo(DataOutput out) throws IOException {
        if (!Search.inited) {
            Search.init();
        }
        write(Center1.ctsmv, out);
        write(Edge3.eprun, out);
    }

    private static void read(int[] arr, DataInput in) throws IOException {
        for (int i = 0, len = arr.length; i < len; i++) {
            arr[i] = in.readInt();
        }
    }

    private static void write(int[] arr, DataOutput out) throws IOException {
        for (int j : arr) {
            out.writeInt(j);
        }
    }

    private static void read(int[][] arr, DataInput in) throws IOException {
        for (int i = 0, leng = arr.length; i < leng; i++) {
            for (int j = 0, len = arr[i].length; j < len; j++) {
                arr[i][j] = in.readInt();
            }
        }
    }

    private static void write(int[][] arr, DataOutput out) throws IOException {
        for (int[] ints : arr) {
            for (int anInt : ints) {
                out.writeInt(anInt);
            }
        }
    }
}
