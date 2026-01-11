package org.worldcubeassociation.tnoodle.scrambleanalysis.statistics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

public class DistributionTest {
    @Test
    public void minimumSampleSizeTest() {
        assertTrue(Distribution.minimumSampleSize() > 0);
        assertEquals(6144, Distribution.minimumSampleSize());
    }
}
