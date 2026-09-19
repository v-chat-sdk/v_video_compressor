package com.v_chat_sdk.v_video_compressor

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class VVideoEncodingSettingsTest {
    @Test
    fun targetBitrate_usesQualityPresetsAnd4kScaling() {
        assertEquals(
            1_800_000,
            VVideoEncodingSettings.targetBitrate(
                width = 1280,
                height = 720,
                quality = VVideoCompressQuality.MEDIUM,
                advanced = null
            )
        )
        assertEquals(
            4_800_000,
            VVideoEncodingSettings.targetBitrate(
                width = 3840,
                height = 2160,
                quality = VVideoCompressQuality.MEDIUM,
                advanced = null
            )
        )
    }

    @Test
    fun targetBitrate_explicitValueOverridesEveryOptimization() {
        assertEquals(
            75_000,
            VVideoEncodingSettings.targetBitrate(
                width = 1280,
                height = 720,
                quality = VVideoCompressQuality.MEDIUM,
                advanced = VVideoAdvancedConfig(
                    videoBitrate = 75_000,
                    aggressiveCompression = true,
                    reducedFrameRate = 15.0,
                    variableBitrate = true
                )
            )
        )
    }

    @Test
    fun targetBitrate_appliesExistingAutomaticOptimizations() {
        assertEquals(
            535_500,
            VVideoEncodingSettings.targetBitrate(
                width = 1280,
                height = 720,
                quality = VVideoCompressQuality.MEDIUM,
                advanced = VVideoAdvancedConfig(
                    aggressiveCompression = true,
                    reducedFrameRate = 15.0,
                    variableBitrate = true
                )
            )
        )
    }

    @Test
    fun effectiveFrameRate_neverUpsamplesTheSource() {
        assertEquals(30.0, VVideoEncodingSettings.effectiveFrameRate(30.0, 60.0))
        assertEquals(24.0, VVideoEncodingSettings.effectiveFrameRate(60.0, 24.0))
        assertEquals(25.0, VVideoEncodingSettings.effectiveFrameRate(25.0, null))
        assertEquals(50.0, VVideoEncodingSettings.effectiveFrameRate(null, 50.0))
        assertEquals(30.0, VVideoEncodingSettings.effectiveFrameRate(null, null))
    }

    @Test
    fun frameDropTarget_onlyReturnsRateThatCanReduceFrames() {
        assertEquals(30.0, VVideoEncodingSettings.frameDropTarget(30.0, 60.0))
        assertEquals(30.0, VVideoEncodingSettings.frameDropTarget(30.0, null))
        assertNull(VVideoEncodingSettings.frameDropTarget(60.0, 30.0))
        assertNull(VVideoEncodingSettings.frameDropTarget(30.0, 30.0))
        assertNull(VVideoEncodingSettings.frameDropTarget(null, 60.0))
    }
}
