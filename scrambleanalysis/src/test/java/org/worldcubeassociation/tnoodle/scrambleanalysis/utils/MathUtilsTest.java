package org.worldcubeassociation.tnoodle.scrambleanalysis.utils;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

public class MathUtilsTest {

    @Test
    public void test() {
        assertEquals(28, MathUtils.nCp(8, 2));
    }

}
