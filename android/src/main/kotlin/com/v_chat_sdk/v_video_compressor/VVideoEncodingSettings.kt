package com.v_chat_sdk.v_video_compressor

import kotlin.math.min

/**
 * Pure helpers for resolving Android video encoder settings.
 *
 * Keeping this logic independent from [VVideoCompressionEngine] makes bitrate and frame-rate
 * precedence testable without constructing Android codecs.
 */
internal object VVideoEncodingSettings {
    const val BITRATE_4K_HIGH = 8_000_000
    const val BITRATE_1080P_HIGH = 3_500_000
    const val BITRATE_720P_MEDIUM = 1_800_000
    const val BITRATE_480P_LOW = 500_000
    const val BITRATE_360P_VERY_LOW = 300_000
    const val BITRATE_240P_ULTRA_LOW = 200_000
    const val DEFAULT_FRAME_RATE = 30.0

    fun targetBitrate(
        width: Int,
        height: Int,
        quality: VVideoCompressQuality,
        advanced: VVideoAdvancedConfig?
    ): Int {
        val baseBitrate = if (width >= 3840 || height >= 2160) {
            when (quality) {
                VVideoCompressQuality.HIGH -> BITRATE_4K_HIGH
                VVideoCompressQuality.MEDIUM -> (BITRATE_4K_HIGH * 0.6).toInt()
                VVideoCompressQuality.LOW -> (BITRATE_4K_HIGH * 0.4).toInt()
                VVideoCompressQuality.VERY_LOW -> (BITRATE_4K_HIGH * 0.25).toInt()
                VVideoCompressQuality.ULTRA_LOW -> (BITRATE_4K_HIGH * 0.15).toInt()
            }
        } else {
            when (quality) {
                VVideoCompressQuality.HIGH -> BITRATE_1080P_HIGH
                VVideoCompressQuality.MEDIUM -> BITRATE_720P_MEDIUM
                VVideoCompressQuality.LOW -> BITRATE_480P_LOW
                VVideoCompressQuality.VERY_LOW -> BITRATE_360P_VERY_LOW
                VVideoCompressQuality.ULTRA_LOW -> BITRATE_240P_ULTRA_LOW
            }
        }

        if (advanced == null) return baseBitrate
        advanced.videoBitrate?.let { return it }

        var bitrate = baseBitrate
        if (advanced.aggressiveCompression == true) {
            bitrate = (bitrate * 0.7f).toInt()
        }
        advanced.reducedFrameRate
            ?.takeIf { it < DEFAULT_FRAME_RATE }
            ?.let { bitrate = (bitrate * (it / DEFAULT_FRAME_RATE)).toInt() }
        if (advanced.variableBitrate == true) {
            bitrate = (bitrate * 0.85f).toInt()
        }

        return maxOf(bitrate, 100_000)
    }

    /** Returns the output rate used for capability checks and H.264 level selection. */
    fun effectiveFrameRate(requested: Double?, source: Double?): Double {
        val validRequested = requested?.takeIf { it.isFinite() && it > 0.0 }
        val validSource = source?.takeIf { it.isFinite() && it > 0.0 }
        return when {
            validRequested != null && validSource != null -> min(validRequested, validSource)
            validRequested != null -> validRequested
            validSource != null -> validSource
            else -> DEFAULT_FRAME_RATE
        }
    }

    /**
     * Returns a frame-drop target only when the request can lower the source rate.
     * FrameDropEffect does not synthesize frames for requests above the source rate.
     */
    fun frameDropTarget(requested: Double?, source: Double?): Double? {
        val validRequested = requested?.takeIf { it.isFinite() && it > 0.0 } ?: return null
        val validSource = source?.takeIf { it.isFinite() && it > 0.0 }
        return if (validSource == null || validRequested < validSource) validRequested else null
    }
}
