package com.v_chat_sdk.v_video_compressor

import android.media.MediaCodecInfo.CodecProfileLevel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class VVideoH264LevelTest {
    @Test
    fun minimumLevel_matchesTableA1ForCommonOutputs() {
        val cases = listOf(
            Triple(320, 240, 15.0) to CodecProfileLevel.AVCLevel12,
            Triple(640, 360, 30.0) to CodecProfileLevel.AVCLevel3,
            // 480x848@30 is the export from androidx/media#2603; the encoder needed 3.1, not 6.0.
            Triple(480, 848, 30.0) to CodecProfileLevel.AVCLevel31,
            Triple(1280, 720, 30.0) to CodecProfileLevel.AVCLevel31,
            Triple(1280, 720, 60.0) to CodecProfileLevel.AVCLevel32,
            Triple(1920, 1080, 30.0) to CodecProfileLevel.AVCLevel4,
            Triple(1920, 1080, 60.0) to CodecProfileLevel.AVCLevel42,
            Triple(3840, 2160, 30.0) to CodecProfileLevel.AVCLevel51,
            Triple(3840, 2160, 60.0) to CodecProfileLevel.AVCLevel52,
            Triple(7680, 4320, 30.0) to CodecProfileLevel.AVCLevel6,
            Triple(7680, 4320, 120.0) to CodecProfileLevel.AVCLevel62
        )

        cases.forEach { (input, expected) ->
            val (width, height, frameRate) = input
            assertEquals(
                expected,
                VVideoH264Level.minimumLevel(width, height, frameRate),
                "${width}x$height @ $frameRate fps"
            )
        }
    }

    @Test
    fun minimumLevel_roundsPartialMacroblocksUp() {
        // 1080 rows are 67.5 macroblocks; the stream must be sized as 68 rows (8160 MBs).
        // At 30.2 fps that is 246432 MB/s, above Level 4's 245760, so 4.2 is required.
        assertEquals(CodecProfileLevel.AVCLevel4, VVideoH264Level.minimumLevel(1920, 1080, 30.0))
        assertEquals(CodecProfileLevel.AVCLevel42, VVideoH264Level.minimumLevel(1920, 1080, 30.2))
    }

    @Test
    fun minimumLevel_isOrientationIndependent() {
        assertEquals(
            VVideoH264Level.minimumLevel(1920, 1080, 30.0),
            VVideoH264Level.minimumLevel(1080, 1920, 30.0)
        )
    }

    @Test
    fun minimumLevel_appliesPerDimensionMacroblockCap() {
        // 4096x64 is only 1024 macroblocks, but a 256-macroblock-wide picture needs
        // sqrt(8 * MaxFS) >= 256, which Level 4 (MaxFS 8192) is the first to satisfy.
        assertEquals(CodecProfileLevel.AVCLevel4, VVideoH264Level.minimumLevel(4096, 64, 1.0))
    }

    @Test
    fun minimumLevel_returnsNullForUnsupportedStreamsAndInvalidInput() {
        assertNull(VVideoH264Level.minimumLevel(7680, 4320, 130.0))
        assertNull(VVideoH264Level.minimumLevel(0, 1080, 30.0))
        assertNull(VVideoH264Level.minimumLevel(1920, -1, 30.0))
        assertNull(VVideoH264Level.minimumLevel(1920, 1080, 0.0))
        assertNull(VVideoH264Level.minimumLevel(1920, 1080, Double.NaN))
    }
}
