package com.v_chat_sdk.v_video_compressor

import android.media.MediaCodecInfo.CodecProfileLevel
import kotlin.math.ceil
import kotlin.math.sqrt

/**
 * Picks the lowest H.264 level whose decoder limits cover an output stream.
 *
 * When no profile/level is requested, Media3's DefaultEncoderFactory asks the encoder for the
 * highest level it advertises (androidx/media#2603). Many encoders write that level into the
 * stream unchanged, so even a 720p export can be declared as High@L6.x and be rejected by
 * decoders that stop at L5.x, such as iOS and Safari. Requesting the level implied by the frame
 * size and frame rate keeps the declared level in line with what the stream actually needs.
 *
 * Limits follow ITU-T H.264 Table A-1 (MaxFS, MaxMBPS). Bitrate limits are not modelled: the
 * requested level is advisory and Media3 clamps the bitrate to the encoder's own range.
 */
internal object VVideoH264Level {
    private const val MACROBLOCK_SIZE = 16

    /** One row of Table A-1: level constant, MaxFS (macroblocks), MaxMBPS (macroblocks/s). */
    private data class Limit(val level: Int, val maxFrameSize: Int, val maxMacroblockRate: Long)

    // Levels 2 and 4.1 share MaxFS/MaxMBPS with 1.3 and 4 and differ only in bitrate limits,
    // so they can never be selected and are omitted.
    private val LIMITS = listOf(
        Limit(CodecProfileLevel.AVCLevel1, 99, 1_485),
        Limit(CodecProfileLevel.AVCLevel11, 396, 3_000),
        Limit(CodecProfileLevel.AVCLevel12, 396, 6_000),
        Limit(CodecProfileLevel.AVCLevel13, 396, 11_880),
        Limit(CodecProfileLevel.AVCLevel21, 792, 19_800),
        Limit(CodecProfileLevel.AVCLevel22, 1_620, 20_250),
        Limit(CodecProfileLevel.AVCLevel3, 1_620, 40_500),
        Limit(CodecProfileLevel.AVCLevel31, 3_600, 108_000),
        Limit(CodecProfileLevel.AVCLevel32, 5_120, 216_000),
        Limit(CodecProfileLevel.AVCLevel4, 8_192, 245_760),
        Limit(CodecProfileLevel.AVCLevel42, 8_704, 522_240),
        Limit(CodecProfileLevel.AVCLevel5, 22_080, 589_824),
        Limit(CodecProfileLevel.AVCLevel51, 36_864, 983_040),
        Limit(CodecProfileLevel.AVCLevel52, 36_864, 2_073_600),
        Limit(CodecProfileLevel.AVCLevel6, 139_264, 4_177_920),
        Limit(CodecProfileLevel.AVCLevel61, 139_264, 8_355_840),
        Limit(CodecProfileLevel.AVCLevel62, 139_264, 16_711_680),
    )

    /**
     * Returns the lowest `MediaCodecInfo.CodecProfileLevel.AVCLevel*` constant that can carry a
     * [width]x[height] stream at [frameRate], or null when the stream exceeds Level 6.2 or an
     * argument is not positive.
     */
    fun minimumLevel(width: Int, height: Int, frameRate: Double): Int? {
        if (width <= 0 || height <= 0 || frameRate.isNaN() || frameRate <= 0.0) return null

        val widthMbs = ceilDiv(width, MACROBLOCK_SIZE)
        val heightMbs = ceilDiv(height, MACROBLOCK_SIZE)
        val frameSize = widthMbs * heightMbs
        val macroblockRate = ceil(frameSize * frameRate).toLong()

        return LIMITS.firstOrNull { limit ->
            // Table A-1 also caps each picture dimension at sqrt(8 * MaxFS) macroblocks.
            val maxDimensionMbs = sqrt(8.0 * limit.maxFrameSize).toInt()
            frameSize <= limit.maxFrameSize &&
                macroblockRate <= limit.maxMacroblockRate &&
                widthMbs <= maxDimensionMbs &&
                heightMbs <= maxDimensionMbs
        }?.level
    }

    private fun ceilDiv(value: Int, divisor: Int): Int = (value + divisor - 1) / divisor
}
