package org.worldcubeassociation.tnoodle.scrambles

import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.random.RandomGenerator
import java.util.random.RandomGeneratorFactory

object SeededRng {
    private val DEFAULT_SECURE_RANDOM: SecureRandom = SecureRandom()

    @JvmStatic
    @JvmOverloads
    fun create(seed: ByteArray, algorithm: String = "L64X128MixRandom"): RandomGenerator {
        val factory: RandomGeneratorFactory<RandomGenerator> = try {
            RandomGeneratorFactory.of(algorithm)
        } catch (_: IllegalArgumentException) {
            RandomGeneratorFactory.getDefault()
        }

        return factory.create(seedToLong(seed))
    }

    @JvmStatic
    fun createWithoutSeed(): SecureRandom = DEFAULT_SECURE_RANDOM

    private fun seedToLong(seed: ByteArray): Long {
        val digest = MessageDigest.getInstance("SHA-256").digest(seed)
        return ByteBuffer.wrap(digest, 0, Long.SIZE_BYTES).long
    }
}
