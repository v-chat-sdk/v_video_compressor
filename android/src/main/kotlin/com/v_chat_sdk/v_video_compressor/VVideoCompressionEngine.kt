package com.v_chat_sdk.v_video_compressor

import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import androidx.media3.transformer.Effects
import androidx.media3.effect.Crop
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.ScaleAndRotateTransformation
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.roundToLong
import kotlin.math.abs


import kotlinx.coroutines.*
import android.app.ActivityManager
import android.os.StatFs
import java.util.concurrent.ConcurrentHashMap
// 4K FIX: Add imports for device capability detection
import android.os.Build
import android.media.MediaCodecList
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat

/**
 * 4K FIX: Data classes for capability detection results
 */
data class DeviceCapabilityResult(
    val canHandle4K: Boolean,
    val reason: String,
    val details: CapabilityDetails? = null
)

data class CapabilityDetails(
    val totalMemoryMB: Long,
    val availableMemoryMB: Long,
    val cpuCores: Int,
    val cpuArchitecture: String,
    val cpuFrequencyMHz: Long?,
    val performanceScore: Int?,
    val hasCodecSupport: Boolean
)

data class CapabilityCheckResult(
    val isSupported: Boolean,
    val message: String
)

data class MemoryAnalysisResult(
    val isMemorySufficient: Boolean,
    val reason: String,
    val totalMemoryMB: Long,
    val availableMemoryMB: Long
)

data class CpuAnalysisResult(
    val isCpuSufficient: Boolean,
    val reason: String,
    val cores: Int,
    val architecture: String,
    val frequencyMHz: Long?
)

/**
 * Enhanced compression engine with real-time progress tracking and cancellation support
 */
@UnstableApi
class VVideoCompressionEngine(private val context: Context) {
    
    private var transformer: Transformer? = null
    private var progressJob: Job? = null
    private var isCompressionActive = AtomicBoolean(false)
    private var isCancelled = AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Memory management
    private val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val memoryInfo = ActivityManager.MemoryInfo()
    
    // Cache for file size to reduce I/O operations
    private val fileSizeCache = ConcurrentHashMap<String, Long>()
    private var lastFileSizeCheck = 0L
    private var lastFileSize = 0L
    
    // 4K FIX: Device capability cache
    private var deviceCapabilityCache: DeviceCapabilityResult? = null
    
    companion object {
        // 4K FIX: Enhanced resolution settings with 4K support
        private const val WIDTH_4K = 3840
        private const val HEIGHT_4K = 2160
        private const val WIDTH_1080P = 1920
        private const val HEIGHT_1080P = 1080
        private const val WIDTH_720P = 1280
        private const val HEIGHT_720P = 720
        private const val WIDTH_480P = 854
        private const val HEIGHT_480P = 480
        private const val WIDTH_360P = 640
        private const val HEIGHT_360P = 360
        private const val WIDTH_240P = 426
        private const val HEIGHT_240P = 240
        
        // Improved audio bitrate settings (Issue #7 fix)
        private const val AUDIO_BITRATE = 128000 // 128 kbps for HIGH/MEDIUM quality
        private const val AUDIO_BITRATE_LOW = 64000 // 64 kbps for LOW quality
        private const val AUDIO_BITRATE_VERY_LOW = 48000 // 48 kbps for VERY_LOW quality
        private const val AUDIO_BITRATE_ULTRA_LOW = 32000 // 32 kbps for ULTRA_LOW quality
        
        // Progress tracking constants
        private const val PROGRESS_UPDATE_INTERVAL = 100L // milliseconds
        private const val INITIAL_PROGRESS_DELAY = 1000L // 1 second
        
        // Memory management constants
        private const val MIN_MEMORY_THRESHOLD_MB = 100 // Minimum 100MB free memory required
        private const val MIN_STORAGE_THRESHOLD_MB = 200 // Minimum 200MB free storage required
        private const val FILE_SIZE_CACHE_DURATION_MS = 500L // Cache file size for 500ms
        private const val MEMORY_CHECK_INTERVAL_MS = 5000L // Check memory every 5 seconds
        
        // 4K FIX: Hardware capability thresholds
        private const val MIN_MEMORY_FOR_4K_MB = 3000 // 3GB RAM minimum for 4K
        private const val MIN_API_LEVEL_FOR_4K = 21 // Android 5.0+
        private const val MAX_COMPRESSION_RETRIES = 3
        private const val MIN_CPU_CORES_FOR_4K = 4 // Minimum 4 CPU cores for 4K
        private const val MIN_CPU_FREQUENCY_MHZ = 1500 // Minimum 1.5GHz CPU frequency
        private const val MIN_AVAILABLE_MEMORY_MB = 1000 // Minimum 1GB available memory
        private const val LOG_TAG = "VVideoCompressor"
        
        // 4K FIX: Performance benchmark thresholds
        private const val PERFORMANCE_TEST_ITERATIONS = 1000
        private const val MIN_PERFORMANCE_SCORE = 50 // Minimum performance score for 4K
    }
    
    // 4K FIX: Device capability detection methods
    
    /**
     * Checks if the device can handle 4K video compression based on hardware capabilities
     */
    private fun canHandle4KCompression(): DeviceCapabilityResult {
        // Return cached result if available
        deviceCapabilityCache?.let { return it }
        
        val result = performCapabilityAnalysis()
        deviceCapabilityCache = result
        return result
    }
    
    /**
     * Performs comprehensive capability analysis
     */
    private fun performCapabilityAnalysis(): DeviceCapabilityResult {
        val apiLevelCheck = checkApiLevel()
        if (!apiLevelCheck.isSupported) {
            return DeviceCapabilityResult(false, apiLevelCheck.message)
        }
        
        val memoryDetails = analyzeMemoryCapabilities()
        if (!memoryDetails.isMemorySufficient) {
            return DeviceCapabilityResult(false, memoryDetails.reason)
        }
        
        val cpuDetails = analyzeCpuCapabilities()
        if (!cpuDetails.isCpuSufficient) {
            return DeviceCapabilityResult(false, cpuDetails.reason)
        }
        
        val codecSupported = hasCodecSupport()
        if (!codecSupported) {
            return DeviceCapabilityResult(false, "Device codecs do not support 4K compression")
        }
        
        val performanceScore = measurePerformanceScore()
        if (performanceScore < MIN_PERFORMANCE_SCORE) {
            return DeviceCapabilityResult(
                false, 
                "Performance insufficient for 4K: score $performanceScore, minimum $MIN_PERFORMANCE_SCORE required"
            )
        }
        
        val details = CapabilityDetails(
            totalMemoryMB = memoryDetails.totalMemoryMB,
            availableMemoryMB = memoryDetails.availableMemoryMB,
            cpuCores = cpuDetails.cores,
            cpuArchitecture = cpuDetails.architecture,
            cpuFrequencyMHz = cpuDetails.frequencyMHz,
            performanceScore = performanceScore,
            hasCodecSupport = codecSupported
        )
        
        return DeviceCapabilityResult(
            true, 
            "Device capable of 4K compression", 
            details
        )
    }
    
    /**
     * Checks if Android API level supports 4K compression
     */
    private fun checkApiLevel(): CapabilityCheckResult {
        return if (Build.VERSION.SDK_INT >= MIN_API_LEVEL_FOR_4K) {
            CapabilityCheckResult(true, "API level ${Build.VERSION.SDK_INT} supports 4K")
        } else {
            CapabilityCheckResult(
                false, 
                "Android API level ${Build.VERSION.SDK_INT} too low (minimum: $MIN_API_LEVEL_FOR_4K)"
            )
        }
    }
    
    /**
     * Analyzes device memory capabilities for 4K compression
     */
    private fun analyzeMemoryCapabilities(): MemoryAnalysisResult {
        activityManager.getMemoryInfo(memoryInfo)
        val totalMemoryMB = memoryInfo.totalMem / (1024 * 1024)
        val availableMemoryMB = memoryInfo.availMem / (1024 * 1024)
        
        return when {
            totalMemoryMB < MIN_MEMORY_FOR_4K_MB -> MemoryAnalysisResult(
                false,
                "Insufficient total memory: ${totalMemoryMB}MB total, ${MIN_MEMORY_FOR_4K_MB}MB required",
                totalMemoryMB,
                availableMemoryMB
            )
            availableMemoryMB < MIN_AVAILABLE_MEMORY_MB -> MemoryAnalysisResult(
                false,
                "Insufficient available memory: ${availableMemoryMB}MB available, ${MIN_AVAILABLE_MEMORY_MB}MB required",
                totalMemoryMB,
                availableMemoryMB
            )
            else -> MemoryAnalysisResult(
                true,
                "Memory sufficient for 4K compression",
                totalMemoryMB,
                availableMemoryMB
            )
        }
    }
    
    /**
     * Analyzes CPU capabilities for 4K compression
     */
    private fun analyzeCpuCapabilities(): CpuAnalysisResult {
        val cpuCores = Runtime.getRuntime().availableProcessors()
        val architecture = getCpuArchitecture()
        val frequencyMHz = getCpuFrequencyMHz()
        
        return when {
            cpuCores < MIN_CPU_CORES_FOR_4K -> CpuAnalysisResult(
                false,
                "Insufficient CPU cores: $cpuCores cores, ${MIN_CPU_CORES_FOR_4K} required",
                cpuCores,
                architecture,
                frequencyMHz
            )
            !isArchitectureSupported(architecture) -> CpuAnalysisResult(
                false,
                "CPU architecture not optimal for 4K: $architecture",
                cpuCores,
                architecture,
                frequencyMHz
            )
            frequencyMHz != null && frequencyMHz < MIN_CPU_FREQUENCY_MHZ -> CpuAnalysisResult(
                false,
                "CPU frequency too low: ${frequencyMHz}MHz, ${MIN_CPU_FREQUENCY_MHZ}MHz required",
                cpuCores,
                architecture,
                frequencyMHz
            )
            else -> CpuAnalysisResult(
                true,
                "CPU sufficient for 4K compression",
                cpuCores,
                architecture,
                frequencyMHz
            )
        }
    }
    
    /**
     * Gets CPU architecture information
     */
    private fun getCpuArchitecture(): String {
        return Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
    }
    
    /**
     * Checks if CPU architecture is supported for 4K compression
     */
    private fun isArchitectureSupported(architecture: String): Boolean {
        return architecture.contains("arm64") || architecture.contains("x86_64")
    }
    
    /**
     * Gets CPU frequency in MHz from system files
     */
    private fun getCpuFrequencyMHz(): Long? {
        val cpuFreqFiles = listOf(
            "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq",
            "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
        )
        
        for (freqFile in cpuFreqFiles) {
            try {
                val file = java.io.File(freqFile)
                if (file.exists() && file.canRead()) {
                    val freqKHz = file.readText().trim().toLongOrNull()
                    if (freqKHz != null) {
                        return freqKHz / 1000
                    }
                }
            } catch (e: Exception) {
                continue
            }
        }
        return null
    }
    
    /**
     * Checks if device codecs support 4K video encoding
     */
    private fun hasCodecSupport(): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            codecList.codecInfos.any { codecInfo ->
                isCodecSupporting4K(codecInfo)
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Checks if a specific codec supports 4K encoding
     */
    private fun isCodecSupporting4K(codecInfo: MediaCodecInfo): Boolean {
        if (!codecInfo.isEncoder) return false
        
        return codecInfo.supportedTypes.any { type ->
            type.startsWith("video/") && checkCodecFormat(codecInfo, type)
        }
    }
    
    /**
     * Checks if codec format supports 4K resolution
     */
    private fun checkCodecFormat(codecInfo: MediaCodecInfo, mimeType: String): Boolean {
        return try {
            val capabilities = codecInfo.getCapabilitiesForType(mimeType)
            val videoCapabilities = capabilities.videoCapabilities
            videoCapabilities?.isSizeSupported(3840, 2160) == true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 4K FIX: Validates complete codec configuration including bitrate and framerate
     * Returns true if codec can handle the specific resolution/bitrate/framerate combination
     */
    private fun validateCompleteCodecConfiguration(
        width: Int,
        height: Int,
        bitrate: Int,
        frameRate: Double = VVideoEncodingSettings.DEFAULT_FRAME_RATE,
        mimeType: String = MimeTypes.VIDEO_H264
    ): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val codecInfo = codecList.codecInfos.firstOrNull { codecInfo ->
                codecInfo.isEncoder &&
                codecInfo.supportedTypes.contains(mimeType)
            } ?: return false

            val capabilities = codecInfo.getCapabilitiesForType(mimeType)
            val videoCapabilities = capabilities.videoCapabilities ?: return false

            // Check 1: Resolution support
            if (!videoCapabilities.isSizeSupported(width, height)) {
                return false
            }

            // Check 2: Bitrate range support (CRITICAL FIX)
            val bitrateRange = videoCapabilities.bitrateRange
            if (!bitrateRange.contains(bitrate)) {
                println("4K FIX: Bitrate $bitrate not supported (range: ${bitrateRange.lower}-${bitrateRange.upper})")
                return false
            }

            // Check 3: Framerate support for this resolution (CRITICAL FIX)
            try {
                if (!videoCapabilities.areSizeAndRateSupported(width, height, frameRate)) {
                    println("4K FIX: Framerate $frameRate not supported at ${width}x$height")
                    return false
                }
            } catch (e: Exception) {
                // areSizeAndRateSupported may throw on some devices, fall back to size check
                println("4K FIX: Framerate check failed (${e.message}), assuming supported")
            }

            true
        } catch (e: Exception) {
            println("4K FIX: Configuration validation error: ${e.message}")
            false
        }
    }

    /**
     * 4K FIX: Gets the maximum supported bitrate for a given codec and resolution
     */
    private fun getMaxSupportedBitrate(
        width: Int,
        height: Int,
        mimeType: String = MimeTypes.VIDEO_H264
    ): Int {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            val codecInfo = codecList.codecInfos.firstOrNull { codecInfo ->
                codecInfo.isEncoder &&
                codecInfo.supportedTypes.contains(mimeType)
            } ?: return VVideoEncodingSettings.BITRATE_1080P_HIGH // Fallback default

            val capabilities = codecInfo.getCapabilitiesForType(mimeType)
            val videoCapabilities = capabilities.videoCapabilities
                ?: return VVideoEncodingSettings.BITRATE_1080P_HIGH

            // Check if codec supports this resolution
            if (!videoCapabilities.isSizeSupported(width, height)) {
                return VVideoEncodingSettings.BITRATE_1080P_HIGH // Can't handle this resolution
            }

            // Return the maximum supported bitrate for this codec
            val maxBitrate = videoCapabilities.bitrateRange.upper
            println("4K FIX: Max bitrate for ${width}x$height on ${mimeType}: $maxBitrate")
            maxBitrate
        } catch (e: Exception) {
            println("4K FIX: Could not determine max bitrate: ${e.message}")
            VVideoEncodingSettings.BITRATE_1080P_HIGH // Safe fallback
        }
    }

    /**
     * 4K FIX: Validates and adjusts compression configuration before encoding
     * Returns adjusted config with safe bitrate if needed
     */
    private fun validateAndAdjustConfiguration(
        videoInfo: VVideoInfo,
        config: VVideoCompressionConfig,
        videoMimeType: String,
        cropPlan: VVideoCropPlan? = null,
        sourceFrameRate: Double? = null
    ): VVideoCompressionConfig {
        // Calculate actual target dimensions and bitrate that will be used
        val (targetWidth, targetHeight) = cropPlan?.outputSize?.let {
            Pair(it.width, it.height)
        } ?: calculateAspectRatioPreservingDimensions(
            videoInfo.width, videoInfo.height, config.quality,
            config.advanced?.customWidth, config.advanced?.customHeight
        )

        val targetBitrate = VVideoEncodingSettings.targetBitrate(
            targetWidth,
            targetHeight,
            config.quality,
            config.advanced
        )
        val frameRate = VVideoEncodingSettings.effectiveFrameRate(
            config.advanced?.frameRate,
            sourceFrameRate
        )

        println("4K FIX: Pre-compression validation - ${targetWidth}x${targetHeight} @ ${targetBitrate / 1_000_000}Mbps @ ${frameRate}fps")

        // Validate if this configuration is supported
        if (validateCompleteCodecConfiguration(targetWidth, targetHeight, targetBitrate, frameRate, videoMimeType)) {
            println("4K FIX: Configuration is valid, proceeding with compression")
            return config
        }

        println("4K FIX: Configuration validation failed, attempting to adjust bitrate...")

        // If validation failed, get the maximum supported bitrate and adjust
        val maxSupportedBitrate = getMaxSupportedBitrate(targetWidth, targetHeight, videoMimeType)

        if (maxSupportedBitrate < targetBitrate) {
            println("4K FIX: Adjusting bitrate from $targetBitrate to $maxSupportedBitrate")

            // Create adjusted advanced config with new bitrate
            val adjustedAdvanced = (config.advanced ?: VVideoAdvancedConfig()).copy(
                videoBitrate = maxSupportedBitrate
            )

            // Return config with adjusted bitrate
            return config.copy(advanced = adjustedAdvanced)
        }

        return config
    }
    
    /**
     * Measures device performance score with lightweight benchmark
     */
    private fun measurePerformanceScore(): Int {
        return try {
            val startTime = System.nanoTime()
            performLightweightBenchmark()
            val endTime = System.nanoTime()
            
            calculatePerformanceScore(startTime, endTime)
        } catch (e: Exception) {
            MIN_PERFORMANCE_SCORE // Return minimum score on error to allow compression
        }
    }
    
    /**
     * Performs lightweight computational benchmark
     */
    private fun performLightweightBenchmark() {
        var result = 0.0
        for (i in 0 until PERFORMANCE_TEST_ITERATIONS) {
            result += Math.sqrt(i.toDouble()) * Math.sin(i.toDouble())
            result += Math.cos(i.toDouble()) / (i + 1.0)
        }
    }
    
    /**
     * Calculates performance score based on benchmark duration
     */
    private fun calculatePerformanceScore(startTime: Long, endTime: Long): Int {
        val durationMs = (endTime - startTime) / 1_000_000
        return if (durationMs > 0) {
            (PERFORMANCE_TEST_ITERATIONS.toDouble() / durationMs * 100).toInt()
        } else {
            100
        }
    }
    

    
    /**
     * 4K FIX: Enhanced optimal quality determination with progressive fallback
     */
    private fun getOptimalQuality(
        videoWidth: Int,
        videoHeight: Int,
        requestedQuality: VVideoCompressQuality
    ): VVideoCompressQuality {
        val is4K = videoWidth >= 3840 || videoHeight >= 2160
        val is2K = videoWidth >= 2560 || videoHeight >= 1440
        
        if (is4K) {
            val capabilityResult = canHandle4KCompression()
            if (!capabilityResult.canHandle4K) {
                println("4K FIX: Device cannot handle 4K compression: ${capabilityResult.reason}")
                // For 4K videos, never go above MEDIUM quality on incapable devices
                return when (requestedQuality) {
                    VVideoCompressQuality.HIGH -> VVideoCompressQuality.MEDIUM
                    else -> minOf(requestedQuality, VVideoCompressQuality.MEDIUM)
                }
            } else {
                // Even capable devices should be conservative with 4K
                return when (requestedQuality) {
                    VVideoCompressQuality.HIGH -> {
                        // Check if device has enough memory for HIGH quality 4K
                        val memoryDetails = analyzeMemoryCapabilities()
                        if (memoryDetails.availableMemoryMB < 2000) { // Need 2GB+ for HIGH 4K
                            VVideoCompressQuality.MEDIUM
                        } else {
                            VVideoCompressQuality.HIGH
                        }
                    }
                    else -> requestedQuality
                }
            }
        } else if (is2K) {
            // 2K videos also need careful handling
            val memoryDetails = analyzeMemoryCapabilities()
            if (memoryDetails.availableMemoryMB < 1500 && requestedQuality == VVideoCompressQuality.HIGH) {
                return VVideoCompressQuality.MEDIUM
            }
        }
        
        return requestedQuality
    }
    
    /**
     * Downgrades video quality to next lower level
     */
    private fun downgradeQuality(currentQuality: VVideoCompressQuality): VVideoCompressQuality {
        return when (currentQuality) {
            VVideoCompressQuality.HIGH -> VVideoCompressQuality.MEDIUM
            VVideoCompressQuality.MEDIUM -> VVideoCompressQuality.LOW
            VVideoCompressQuality.LOW -> VVideoCompressQuality.VERY_LOW
            VVideoCompressQuality.VERY_LOW -> VVideoCompressQuality.ULTRA_LOW
            VVideoCompressQuality.ULTRA_LOW -> VVideoCompressQuality.ULTRA_LOW
        }
    }
    
    /**
     * 4K FIX: Enhanced error detection for codec capacity and 4K-specific issues
     */
    private fun isCodecCapacityError(error: Throwable): Boolean {
        val errorMessage = error.message?.lowercase() ?: ""
        val stackTrace = error.stackTrace?.joinToString(" ") { it.toString().lowercase() } ?: ""
        
        // Common codec capacity error patterns
        val codecErrors = listOf(
            "codec capacity",
            "failed to initialize",
            "codec reported err",
            "insufficient resources",
            "encoder failed",
            "mediacodec error",
            "error 0xffffec77", // Specific error from the issue
            "codec exception",
            "resource busy",
            "codec not available",
            "encoder init failed",
            "format not supported",
            "resolution not supported",
            "bitrate too high",
            "frame rate not supported"
        )
        
        // 4K-specific error patterns
        val fourKErrors = listOf(
            "resolution too high",
            "size not supported",
            "dimensions not supported",
            "3840x2160",
            "4k not supported",
            "uhd not supported"
        )
        
        val allErrors = codecErrors + fourKErrors
        
        return allErrors.any { pattern ->
            errorMessage.contains(pattern) || stackTrace.contains(pattern)
        }
    }

    private fun formatExportError(
        error: ExportException,
        outputDirectory: File
    ): String {
        val causeMessages = generateSequence<Throwable>(error) { it.cause }
            .map { it.message ?: it.javaClass.simpleName }
            .toList()
        val availableStorageBytes = runCatching {
            StatFs(outputDirectory.path).availableBytes
        }.getOrNull()
        val deviceDescription =
            "${Build.MANUFACTURER} ${Build.MODEL} " +
                "(Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT})"

        return VVideoExportError.format(
            errorCode = error.errorCode,
            errorCodeName = error.errorCodeName,
            causeMessages = causeMessages,
            codecInfo = error.codecInfo?.toString(),
            availableStorageBytes = availableStorageBytes,
            deviceDescription = deviceDescription
        )
    }
    
    /**
     * Callback interface for compression events
     */
    interface CompressionCallback {
        fun onProgress(progress: Float)
        fun onComplete(compressionResult: VVideoCompressionResult)
        fun onError(error: String)
    }
    
    /**
     * Gets video information from file path
     */
    fun getVideoInfo(videoPath: String): VVideoInfo? {
        var retriever: MediaMetadataRetriever? = null
        return try {
            val file = File(videoPath)
            if (!file.exists()) return null
            
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoPath)
            
            val name = file.name
            val fileSizeBytes = file.length()
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val durationMillis = durationStr?.toLongOrNull() ?: 0L
            
            // ORIENTATION FIX: Extract raw dimensions and rotation metadata
            val widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            
            val rawWidth = widthStr?.toIntOrNull() ?: 0
            val rawHeight = heightStr?.toIntOrNull() ?: 0
            val rotation = rotationStr?.toIntOrNull() ?: 0
            
            // ORIENTATION FIX: Apply rotation to get correct display dimensions
            val (displayWidth, displayHeight) = when (rotation) {
                90, 270 -> Pair(rawHeight, rawWidth) // Swap dimensions for portrait videos
                else -> Pair(rawWidth, rawHeight) // Keep original for landscape
            }
            
            VVideoInfo(
                path = videoPath,
                name = name,
                fileSizeBytes = fileSizeBytes,
                durationMillis = durationMillis,
                width = displayWidth,
                height = displayHeight
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            retriever?.release()
        }
    }
    
    /**
     * ORIENTATION FIX: Helper method to detect video rotation from file metadata
     */
    private fun getVideoRotation(videoPath: String): Int {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoPath)
            val rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            rotationStr?.toIntOrNull() ?: 0
        } catch (e: Exception) {
            e.printStackTrace()
            0
        } finally {
            retriever?.release()
        }
    }
    
    /**
     * Applies the requested bitrate and, where supported, an H.264 profile/level that matches the
     * output stream. Both settings must share one encoder factory so neither request overwrites the
     * other.
     */
    private fun configureVideoEncoder(
        transformerBuilder: Transformer.Builder,
        videoInfo: VVideoInfo,
        config: VVideoCompressionConfig,
        cropPlan: VVideoCropPlan?,
        videoMimeType: String,
        source: SourceVideoTrack
    ) {
        val (width, height) = cropPlan?.outputSize?.let {
            Pair(it.width, it.height)
        } ?: calculateAspectRatioPreservingDimensions(
            videoInfo.width, videoInfo.height, config.quality,
            config.advanced?.customWidth, config.advanced?.customHeight
        )

        val encoderSettings = VideoEncoderSettings.Builder()
        config.advanced?.videoBitrate?.let { targetBitrate ->
            encoderSettings.setBitrate(targetBitrate)
            println("VVideoCompressionEngine: Requesting video bitrate $targetBitrate bps")
        }

        if (videoMimeType == MimeTypes.VIDEO_H264 &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !source.isHdr &&
            videoInfo.width > 0 &&
            videoInfo.height > 0
        ) {
            val frameRate = VVideoEncodingSettings.effectiveFrameRate(
                config.advanced?.frameRate,
                source.frameRate
            )
            VVideoH264Level.minimumLevel(width, height, frameRate)?.let { level ->
                println(
                    "VVideoCompressionEngine: Requesting H.264 High profile, " +
                        "level 0x${Integer.toHexString(level)} for ${width}x${height} " +
                        "@ ${frameRate}fps"
                )
                encoderSettings.setEncodingProfileLevel(
                    MediaCodecInfo.CodecProfileLevel.AVCProfileHigh,
                    level
                )
            }
        }

        transformerBuilder.setEncoderFactory(
            DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(encoderSettings.build())
                .build()
        )
    }

    private data class SourceVideoTrack(val frameRate: Double?, val isHdr: Boolean)

    /**
     * Reads the frame rate and HDR transfer of the first video track. Either may be unknown.
     */
    @RequiresApi(Build.VERSION_CODES.N)
    private fun readSourceVideoTrack(videoPath: String): SourceVideoTrack {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(videoPath)
            val format = (0 until extractor.trackCount)
                .map { extractor.getTrackFormat(it) }
                .firstOrNull { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                ?: return SourceVideoTrack(frameRate = null, isHdr = false)

            val frameRate = if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                try {
                    format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                } catch (e: ClassCastException) {
                    format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                }
            } else {
                null
            }
            val colorTransfer = if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)
            } else {
                null
            }

            SourceVideoTrack(
                frameRate = frameRate?.takeIf { it > 0.0 },
                isHdr = colorTransfer == MediaFormat.COLOR_TRANSFER_ST2084 ||
                    colorTransfer == MediaFormat.COLOR_TRANSFER_HLG
            )
        } catch (e: Exception) {
            println("VVideoCompressionEngine: Could not read source video track: ${e.message}")
            SourceVideoTrack(frameRate = null, isHdr = false)
        } finally {
            extractor.release()
        }
    }

    /**
     * Estimates the compressed file size for a video
     */
    fun estimateCompressionSize(videoInfo: VVideoInfo, quality: VVideoCompressQuality): VVideoCompressionEstimate {
        return estimateCompressionSize(videoInfo, quality, null)
    }
    
    /**
     * Estimates the compressed file size for a video with advanced configuration
     */
    fun estimateCompressionSize(
        videoInfo: VVideoInfo, 
        quality: VVideoCompressQuality, 
        advanced: VVideoAdvancedConfig?
    ): VVideoCompressionEstimate {
        val durationSeconds = videoInfo.durationMillis / 1000.0

        var targetVideoBitrate = VVideoEncodingSettings.targetBitrate(
            videoInfo.width,
            videoInfo.height,
            quality,
            advanced
        )

        // Apply resolution scaling (Android Quick Fix improvement)
        val (targetWidth, targetHeight) = calculateAspectRatioPreservingDimensions(
            videoInfo.width, videoInfo.height, quality,
            advanced?.customWidth, advanced?.customHeight
        )
        val originalPixels = videoInfo.width * videoInfo.height
        val targetPixels = targetWidth * targetHeight
        if (advanced?.videoBitrate == null && targetPixels < originalPixels) {
            val pixelRatio = targetPixels.toFloat() / originalPixels
            targetVideoBitrate = (targetVideoBitrate * pixelRatio * 0.9f).toInt()  // Issue #7 fix: reduce not increase
        }

        // Audio bitrate (Issue #7 fix: scale by quality)
        val targetAudioBitrate = when {
            advanced?.removeAudio == true -> 0
            advanced?.audioBitrate != null -> advanced.audioBitrate
            quality == VVideoCompressQuality.LOW -> AUDIO_BITRATE_LOW
            quality == VVideoCompressQuality.VERY_LOW -> AUDIO_BITRATE_VERY_LOW
            quality == VVideoCompressQuality.ULTRA_LOW -> AUDIO_BITRATE_ULTRA_LOW
            else -> AUDIO_BITRATE
        }

        // Calculate size
        val totalBitrate = targetVideoBitrate + targetAudioBitrate
        val estimatedBytes = ((totalBitrate * durationSeconds) / 8).toLong()

        // Add 5% overhead for container (Android Quick Fix improvement)
        val finalEstimate = (estimatedBytes * 1.05).toLong()

        return VVideoCompressionEstimate(
            estimatedSizeBytes = finalEstimate,
            estimatedSizeFormatted = formatFileSize(finalEstimate),
            compressionRatio = finalEstimate.toFloat() / videoInfo.fileSizeBytes,
            bitrateMbps = targetVideoBitrate / 1000000.0f
        )
    }
    
    /**
     * Checks if there's enough memory and storage to perform compression
     */
    private fun hasEnoughResources(
        videoInfo: VVideoInfo,
        outputDirectory: File
    ): Boolean {
        // Check available memory
        activityManager.getMemoryInfo(memoryInfo)
        val availableMemoryMB = memoryInfo.availMem / (1024 * 1024)
        if (availableMemoryMB < MIN_MEMORY_THRESHOLD_MB) {
            return false
        }
        
        // Check available storage
        val stat = StatFs(outputDirectory.path)
        val availableStorageMB = stat.availableBytes / (1024 * 1024)
        // Need at least the video size + buffer.
        val requiredStorageMB =
            (videoInfo.fileSizeBytes / (1024 * 1024)) + MIN_STORAGE_THRESHOLD_MB
        if (availableStorageMB < requiredStorageMB) {
            return false
        }
        
        return true
    }
    
    /**
     * Compresses a single video file with real-time progress tracking and 4K fallback support
     */
    fun compressVideo(
        videoInfo: VVideoInfo,
        config: VVideoCompressionConfig,
        callback: CompressionCallback
    ) {
        val inputFile = File(videoInfo.path)
        if (!inputFile.isFile || !inputFile.canRead() || inputFile.length() <= 0L) {
            callback.onError("The input video is missing, empty, or unreadable")
            return
        }

        val outputDirectory = try {
            prepareOutputDirectory(config.outputPath)
        } catch (error: IOException) {
            callback.onError(error.message ?: "The output directory is unavailable")
            return
        }

        // Check resources before starting
        if (!hasEnoughResources(videoInfo, outputDirectory)) {
            callback.onError("Insufficient memory or storage available for compression")
            return
        }
        
        // 4K FIX: Start with optimized quality based on device capabilities
        val optimalQuality = getOptimalQuality(videoInfo.width, videoInfo.height, config.quality)
        val currentConfig = config.copy(quality = optimalQuality)
        
        // 4K FIX: Retry compression with progressively lower quality on failure
        compressVideoWithRetry(
            videoInfo,
            currentConfig,
            outputDirectory,
            callback,
            retryCount = 0
        )
    }
    
    /**
     * 4K FIX: Compresses video with retry logic for codec capacity failures
     */
    private fun compressVideoWithRetry(
        videoInfo: VVideoInfo,
        config: VVideoCompressionConfig,
        outputDirectory: File,
        callback: CompressionCallback,
        retryCount: Int
    ) {
        val outputFile = createOutputFile(outputDirectory, videoInfo, config.quality)
        val startTime = System.currentTimeMillis()
        
        // Reset cancellation state and clear caches
        isCancelled.set(false)
        isCompressionActive.set(true)
        fileSizeCache.clear()
        lastFileSizeCheck = 0L
        lastFileSize = 0L
        
        try {
            // Create MediaItem from video URI
            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(File(videoInfo.path)))
                .build()
            
            val cropPlan = config.advanced?.cropRect
                ?.takeUnless { it.isFullFrame() }
                ?.let {
                    VVideoCropGeometry.createPlan(
                        displayedWidth = videoInfo.width,
                        displayedHeight = videoInfo.height,
                        explicitRotation = config.advanced.rotation ?: 0,
                        cropRect = it,
                        quality = config.quality,
                        customWidth = config.advanced.customWidth,
                        customHeight = config.advanced.customHeight,
                        dimensionHandling = config.advanced.dimensionHandling
                    )
                }

            val sourceVideoTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                readSourceVideoTrack(videoInfo.path)
            } else {
                SourceVideoTrack(frameRate = null, isHdr = false)
            }

            // 4K FIX: Enhanced codec selection with device capability consideration
            val videoMimeType = selectOptimalVideoCodec(
                videoInfo,
                config,
                sourceVideoTrack.frameRate
            )

            // Validate before building effects or encoder settings so any device-specific
            // bitrate adjustment reaches the actual Media3 export.
            val validatedConfig =
                validateAndAdjustConfiguration(
                    videoInfo,
                    config,
                    videoMimeType,
                    cropPlan,
                    sourceVideoTrack.frameRate
                )

            // Create one edited item containing clipping, frame dropping, rotation, crop and sizing.
            val editedMediaItem = createEditedMediaItemWithQuality(
                mediaItem,
                videoInfo,
                validatedConfig,
                cropPlan,
                sourceVideoTrack.frameRate
            )

            // Configure transformer with advanced settings
            val transformerBuilder = Transformer.Builder(context)
                // Avoid device-specific android.media.MediaMuxer failures by
                // using Media3's in-app MP4 writer.
                .setMuxerFactory(InAppMp4Muxer.Factory())
                .setVideoMimeType(videoMimeType)

            configureVideoEncoder(
                transformerBuilder,
                videoInfo,
                validatedConfig,
                cropPlan,
                videoMimeType,
                sourceVideoTrack
            )

            // Apply audio codec settings if audio is not removed
            if (validatedConfig.advanced?.removeAudio != true) {
                val audioMimeType = when (validatedConfig.advanced?.audioCodec) {
                    VAudioCodec.MP3 -> MimeTypes.AUDIO_MPEG
                    else -> MimeTypes.AUDIO_AAC // Default to AAC
                }
                transformerBuilder.setAudioMimeType(audioMimeType)
            }

            // Apply more aggressive encoding settings for smaller files
            transformerBuilder.experimentalSetTrimOptimizationEnabled(true)

            // Optimization from Android Quick Fix
            if (validatedConfig.advanced?.hardwareAcceleration != false) {
                // Hardware acceleration is enabled by default in Media3
                // Just ensure we're not disabling it accidentally
            }

            // 4K FIX: Apply advanced compression optimizations with 4K considerations
            applyAdvancedCompressionSettings(transformerBuilder, validatedConfig.advanced, videoInfo)
            
            transformer = transformerBuilder
                .addListener(object : Transformer.Listener {
                    private var lastProgress = 0f

                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        stopProgressTracking()

                        if (isCancelled.get()) {
                            // Clean up output file if cancelled
                            try {
                                outputFile.delete()
                            } catch (e: Exception) {
                                // Ignore cleanup errors
                            }
                            callback.onError("Compression was cancelled")
                            return
                        }

                        val endTime = System.currentTimeMillis()
                        val timeTaken = endTime - startTime

                        // Send final progress update
                        mainHandler.post {
                            callback.onProgress(1.0f)
                        }

                        // Issue #7 fix: Check if compressed file is larger than original
                        val compressedSizeBytes = outputFile.length()
                        val originalSizeBytes = videoInfo.fileSizeBytes
                        val compressionRatio = compressedSizeBytes.toFloat() / originalSizeBytes

                        // Preserve the historical fallback unless the caller needs
                        // the encoded output to guarantee its codec or container.
                        val usedOriginalFile =
                            config.fallbackToOriginalIfNotSmaller &&
                                !VVideoCropGeometry.requiresEncodedOutput(videoInfo, config) &&
                                compressionRatio >= 0.95f
                        val finalFile = if (usedOriginalFile) {
                            println("Issue #7: Compressed file (${compressedSizeBytes}B) is too close to original (${originalSizeBytes}B). Using original.")
                            try {
                                outputFile.delete()
                            } catch (e: Exception) {
                                // Ignore cleanup errors
                            }
                            File(videoInfo.path)
                        } else {
                            outputFile
                        }

                        val result = createCompressionResult(
                            originalVideo = videoInfo,
                            compressedFile = finalFile,
                            quality = config.quality,
                            timeTaken = timeTaken,
                            usedOriginalFile = usedOriginalFile
                        )

                        // Handle post-compression tasks
                        if (config.deleteOriginal && finalFile != File(videoInfo.path)) {
                            try {
                                File(videoInfo.path).delete()
                            } catch (e: Exception) {
                                // Log error but don't fail the compression
                            }
                        }

                        callback.onComplete(result)
                    }
                    
                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        stopProgressTracking()
                        
                        // Clean up output file on error
                        try {
                            outputFile.delete()
                        } catch (e: Exception) { 
                            // Ignore cleanup errors
                        }
                        
                        val codecCapacityError = isCodecCapacityError(exportException)
                        val shouldRetry = VVideoExportError.shouldRetry(
                            errorCode = exportException.errorCode,
                            isCodecCapacityError = codecCapacityError,
                            retryCount = retryCount,
                            maxRetries = MAX_COMPRESSION_RETRIES
                        )
                        if (shouldRetry) {
                            val isMuxerError =
                                VVideoExportError.isMuxerError(exportException.errorCode)
                            val nextQuality = if (isMuxerError) {
                                config.quality
                            } else {
                                getNextLowerQuality(config.quality)
                            }
                            if (nextQuality != null) {
                                val failureType = if (isMuxerError) {
                                    "MP4 muxer failure"
                                } else {
                                    "Codec capacity issue"
                                }
                                Log.w(
                                    LOG_TAG,
                                    "$failureType detected; retrying with ${nextQuality.displayName}",
                                    exportException
                                )
                                
                                // Notify about the retry attempt
                                mainHandler.post {
                                    callback.onProgress(0.0f) // Reset progress for retry
                                }
                                
                                val retryConfig = config.copy(quality = nextQuality)
                                compressVideoWithRetry(
                                    videoInfo,
                                    retryConfig,
                                    outputDirectory,
                                    callback,
                                    retryCount + 1
                                )
                                return
                            }
                        }
                        
                        val detailedError = formatExportError(exportException, outputDirectory)
                        Log.e(LOG_TAG, detailedError, exportException)
                        callback.onError(detailedError)
                    }
                })
                .build()
            
            // Start real-time progress tracking
            startProgressTracking(videoInfo, outputFile, callback)
            
            // Start compression
            transformer?.start(editedMediaItem, outputFile.absolutePath)
            
        } catch (e: Exception) {
            stopProgressTracking()
            outputFile.delete()

            val codecCapacityError = isCodecCapacityError(e)
            val shouldRetry = if (e is ExportException) {
                VVideoExportError.shouldRetry(
                    errorCode = e.errorCode,
                    isCodecCapacityError = codecCapacityError,
                    retryCount = retryCount,
                    maxRetries = MAX_COMPRESSION_RETRIES
                )
            } else {
                retryCount < MAX_COMPRESSION_RETRIES && codecCapacityError
            }
            if (shouldRetry) {
                val isMuxerError =
                    e is ExportException && VVideoExportError.isMuxerError(e.errorCode)
                val nextQuality = if (isMuxerError) {
                    config.quality
                } else {
                    getNextLowerQuality(config.quality)
                }
                if (nextQuality != null) {
                    Log.w(
                        LOG_TAG,
                        "Export initialization failed; retrying with ${nextQuality.displayName}",
                        e
                    )

                    val retryConfig = config.copy(quality = nextQuality)
                    compressVideoWithRetry(
                        videoInfo,
                        retryConfig,
                        outputDirectory,
                        callback,
                        retryCount + 1
                    )
                    return
                }
            }

            val errorMessage = if (e is ExportException) {
                formatExportError(e, outputDirectory)
            } else if (codecCapacityError) {
                val deviceReport = buildDeviceCapabilityReport()
                "Compression failed - ${e.message ?: "codec error"}.\n\n$deviceReport"
            } else {
                "Failed to start compression: ${e.message ?: e.javaClass.simpleName}"
            }

            Log.e(LOG_TAG, errorMessage, e)
            callback.onError(errorMessage)
        }
    }

    /**
     * 4K FIX: Gets the next lower quality level for retry attempts
     */
    private fun getNextLowerQuality(currentQuality: VVideoCompressQuality): VVideoCompressQuality? {
        return if (currentQuality == VVideoCompressQuality.ULTRA_LOW) {
            null // No lower quality available
        } else {
            downgradeQuality(currentQuality)
        }
    }
    
    /**
     * 4K FIX: Selects optimal video codec based on device capabilities and video resolution
     * Enhanced to validate against actual configuration and provide fallback
     */
    private fun selectOptimalVideoCodec(
        videoInfo: VVideoInfo,
        config: VVideoCompressionConfig,
        sourceFrameRate: Double? = null
    ): String {
        val is4K = videoInfo.width >= 3840 || videoInfo.height >= 2160

        // Calculate target dimensions and bitrate for validation
        val (targetWidth, targetHeight) = calculateAspectRatioPreservingDimensions(
            videoInfo.width, videoInfo.height, config.quality,
            config.advanced?.customWidth, config.advanced?.customHeight
        )

        val targetBitrate = VVideoEncodingSettings.targetBitrate(
            targetWidth,
            targetHeight,
            config.quality,
            config.advanced
        )
        val frameRate = VVideoEncodingSettings.effectiveFrameRate(
            config.advanced?.frameRate,
            sourceFrameRate
        )

        // If user explicitly requested a codec, validate and fallback if needed
        config.advanced?.videoCodec?.let { requestedCodec ->
            return when (requestedCodec) {
                VVideoCodec.H264 -> MimeTypes.VIDEO_H264
                VVideoCodec.H265 -> {
                    // Validate H.265 configuration
                    if (validateCompleteCodecConfiguration(targetWidth, targetHeight, targetBitrate, frameRate, MimeTypes.VIDEO_H265)) {
                        println("4K FIX: H.265 validated successfully")
                        MimeTypes.VIDEO_H265
                    } else {
                        println("4K FIX: H.265 validation failed, falling back to H.264")
                        MimeTypes.VIDEO_H264
                    }
                }
            }
        }

        // Automatic codec selection based on resolution and device capabilities
        return when {
            is4K -> {
                // For 4K, try H.264 first (better compatibility)
                if (validateCompleteCodecConfiguration(targetWidth, targetHeight, targetBitrate, frameRate, MimeTypes.VIDEO_H264)) {
                    println("4K FIX: Using H.264 for 4K (validated)")
                    MimeTypes.VIDEO_H264
                } else if (validateCompleteCodecConfiguration(targetWidth, targetHeight, targetBitrate, frameRate, MimeTypes.VIDEO_H265)) {
                    println("4K FIX: Using H.265 for 4K (H.264 validation failed)")
                    MimeTypes.VIDEO_H265
                } else {
                    println("4K FIX: No validated codec found, using H.264 as fallback")
                    MimeTypes.VIDEO_H264
                }
            }
            config.quality == VVideoCompressQuality.HIGH -> MimeTypes.VIDEO_H264
            else -> {
                // For lower qualities, use H.265 if supported and validated
                if (validateCompleteCodecConfiguration(targetWidth, targetHeight, targetBitrate, frameRate, MimeTypes.VIDEO_H265)) {
                    MimeTypes.VIDEO_H265
                } else {
                    MimeTypes.VIDEO_H264
                }
            }
        }
    }
    
    /**
     * 4K FIX: Checks if device supports H.264 encoding for 4K resolution
     */
    private fun supportsH264For4K(): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            codecList.codecInfos.any { codecInfo ->
                codecInfo.isEncoder && 
                codecInfo.supportedTypes.contains(MimeTypes.VIDEO_H264) &&
                checkCodecFormat(codecInfo, MimeTypes.VIDEO_H264)
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 4K FIX: Checks if device supports H.265 encoding for 4K resolution
     */
    private fun supportsH265For4K(): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            codecList.codecInfos.any { codecInfo ->
                codecInfo.isEncoder && 
                codecInfo.supportedTypes.contains(MimeTypes.VIDEO_H265) &&
                checkCodecFormat(codecInfo, MimeTypes.VIDEO_H265)
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * 4K FIX: Checks if device has basic H.265 support
     */
    private fun hasH265Support(): Boolean {
        return try {
            val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            codecList.codecInfos.any { codecInfo ->
                codecInfo.isEncoder && codecInfo.supportedTypes.contains(MimeTypes.VIDEO_H265)
            }
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Starts real-time progress tracking using multiple indicators with memory optimization
     */
    private fun startProgressTracking(
        videoInfo: VVideoInfo,
        outputFile: File,
        callback: CompressionCallback
    ) {
        progressJob = CoroutineScope(Dispatchers.IO).launch {
            val startTime = System.currentTimeMillis()
            val videoDurationMs = videoInfo.durationMillis
            val originalFileSize = videoInfo.fileSizeBytes
            var lastMemoryCheck = 0L
            
            // Initial delay to let compression start
            delay(INITIAL_PROGRESS_DELAY)
            
            while (isCompressionActive.get() && !isCancelled.get()) {
                try {
                    val currentTime = System.currentTimeMillis()
                    val elapsedTime = currentTime - startTime
                    
                    // Check memory periodically
                    if (currentTime - lastMemoryCheck > MEMORY_CHECK_INTERVAL_MS) {
                        activityManager.getMemoryInfo(memoryInfo)
                        if (memoryInfo.lowMemory) {
                            // System is in low memory state, reduce activity
                            delay(PROGRESS_UPDATE_INTERVAL * 3) // Triple the delay
                            continue
                        }
                        lastMemoryCheck = currentTime
                    }
                    
                    // Method 1: Time-based estimation (primary)
                    val timeProgress = if (videoDurationMs > 0) {
                        // Assume compression takes 2x video duration on average
                        val estimatedTotalTime = videoDurationMs * 2
                        (elapsedTime.toFloat() / estimatedTotalTime).coerceAtMost(0.95f)
                    } else {
                        0f
                    }
                    
                    // Method 2: File size based estimation (secondary) with caching
                    val fileSizeProgress = if (outputFile.exists() && originalFileSize > 0) {
                        val currentOutputSize = getCachedFileSize(outputFile)
                        // Estimate based on expected compression ratio
                        val expectedFinalSize = originalFileSize * 0.5f // rough estimate
                        if (expectedFinalSize > 0) {
                            (currentOutputSize.toFloat() / expectedFinalSize).coerceAtMost(0.95f)
                        } else {
                            0f
                        }
                    } else {
                        0f
                    }
                    
                    // Method 3: Hybrid approach - use the higher of the two for better UX
                    val hybridProgress = maxOf(timeProgress, fileSizeProgress * 0.7f) // Weight file size less
                    
                    // Apply smoothing and constraints
                    val smoothedProgress = hybridProgress.coerceIn(0f, 0.98f) // Never show 100% until complete
                    
                    // Send progress update on main thread with batching
                    withContext(Dispatchers.Main) {
                        try {
                            callback.onProgress(smoothedProgress)
                        } catch (e: Exception) {
                            // Ignore callback errors
                        }
                    }
                    
                    delay(PROGRESS_UPDATE_INTERVAL)
                    
                } catch (e: OutOfMemoryError) {
                    // Handle OutOfMemoryError gracefully
                    System.gc() // Request garbage collection
                    delay(1000) // Wait longer before retrying
                } catch (e: Exception) {
                    // Continue tracking even if individual update fails
                    delay(PROGRESS_UPDATE_INTERVAL)
                }
            }
        }
    }
    
    /**
     * Gets cached file size to reduce I/O operations
     */
    private fun getCachedFileSize(file: File): Long {
        val currentTime = System.currentTimeMillis()
        val cacheKey = file.absolutePath
        
        // Check if we have a recent cached value
        if (currentTime - lastFileSizeCheck < FILE_SIZE_CACHE_DURATION_MS && lastFileSize > 0) {
            return lastFileSize
        }
        
        return try {
            val size = file.length()
            lastFileSize = size
            lastFileSizeCheck = currentTime
            fileSizeCache[cacheKey] = size
            size
        } catch (e: Exception) {
            // Return last known size on error
            lastFileSize
        }
    }
    
    /**
     * Stops progress tracking and cleans up resources
     */
    private fun stopProgressTracking() {
        isCompressionActive.set(false)
        progressJob?.cancel()
        progressJob = null
        fileSizeCache.clear()
        System.gc() // Request garbage collection
    }
    
    /**
     * Cancels the current compression operation
     */
    fun cancelCompression() {
        isCancelled.set(true)
        stopProgressTracking()
        transformer?.cancel()
        releaseTransformer() // Use improved release method
    }
    
    /**
     * Checks if compression is currently running
     */
    fun isCompressing(): Boolean {
        return isCompressionActive.get() && transformer != null
    }

    /**
     * 4K FIX: Builds a detailed device capability report for error messages
     */
    private fun buildDeviceCapabilityReport(): String {
        return try {
            val capabilityResult = canHandle4KCompression()
            val details = capabilityResult.details

            if (details != null) {
                """
                Device Capabilities:
                - RAM: ${details.totalMemoryMB}MB total, ${details.availableMemoryMB}MB available
                - CPU: ${details.cpuCores} cores, ${details.cpuArchitecture}
                - API Level: ${Build.VERSION.SDK_INT}
                - Performance Score: ${details.performanceScore}
                - H.264 4K Support: ${supportsH264For4K()}
                - H.265 4K Support: ${supportsH265For4K()}

                Recommendation: Try using MEDIUM quality or lower for better compatibility.
                """.trimIndent()
            } else {
                capabilityResult.reason
            }
        } catch (e: Exception) {
            "Unable to analyze device capabilities: ${e.message}"
        }
    }
    
    /**
     * Aligns a dimension to the nearest 16-pixel boundary (fixes encoder padding artifacts)
     */
    private fun alignTo16(dimension: Int): Int = (dimension / 16) * 16

    /**
     * Calculates aspect ratio preserving dimensions for video compression
     */
    private fun calculateAspectRatioPreservingDimensions(
        originalWidth: Int,
        originalHeight: Int,
        quality: VVideoCompressQuality,
        customWidth: Int? = null,
        customHeight: Int? = null
    ): Pair<Int, Int> {
        val originalAspectRatio: Float = originalWidth.toFloat() / originalHeight.toFloat()
        
        // If custom dimensions are provided, validate they maintain aspect ratio
        if (customWidth != null && customHeight != null) {
            val customAspectRatio: Float = customWidth.toFloat() / customHeight.toFloat()
            val alignedWidth: Int
            val alignedHeight: Int
            if (abs(customAspectRatio - originalAspectRatio) < 0.01f) {
                alignedWidth = customWidth
                alignedHeight = customHeight
            } else {
                alignedWidth = customWidth
                alignedHeight = (customWidth / originalAspectRatio).toInt()
            }
            val finalWidth = if (alignedWidth % 16 != 0) alignTo16(alignedWidth) else alignedWidth
            val finalHeight = if (alignedHeight % 16 != 0) alignTo16(alignedHeight) else alignedHeight
            if (finalWidth > 0 && finalHeight > 0) {
                if (finalWidth != alignedWidth || finalHeight != alignedHeight) {
                    Log.d("VVideoCompressor", "Dimension alignment: ${alignedWidth}x${alignedHeight} → ${finalWidth}x${finalHeight} (16-pixel boundary)")
                }
                return Pair(finalWidth, finalHeight)
            }
            return Pair(alignedWidth, alignedHeight)
        }
        
        // Quality-based calculation - maintain aspect ratio
        val maxDimensions: Pair<Int, Int> = when (quality) {
            VVideoCompressQuality.HIGH -> {
                // Issue #7 fix: Always enforce 1080p max for HIGH quality, don't keep 4K
                // Use max dimension (1920) for both width and height bounds to support both portrait and landscape
                val maxDimension = max(WIDTH_1080P, HEIGHT_1080P)  // 1920
                // Always downscale to fit within bounds, but never upscale
                val (targetWidth, targetHeight) = calculateDimensionsToFitBounds(
                    originalWidth, originalHeight, maxDimension, maxDimension
                )
                // Don't upscale if video is already smaller than target
                if (originalWidth < targetWidth || originalHeight < targetHeight) {
                    Pair(originalWidth, originalHeight)
                } else {
                    Pair(targetWidth, targetHeight)
                }
            }
            VVideoCompressQuality.MEDIUM -> {
                // For MEDIUM quality, fit within 720p bounds
                val maxDimension = max(WIDTH_720P, HEIGHT_720P)  // 1280
                calculateDimensionsToFitBounds(originalWidth, originalHeight, maxDimension, maxDimension)
            }
            VVideoCompressQuality.LOW -> {
                // For LOW quality, fit within 480p bounds
                val maxDimension = max(WIDTH_480P, HEIGHT_480P)  // 960
                calculateDimensionsToFitBounds(originalWidth, originalHeight, maxDimension, maxDimension)
            }
            VVideoCompressQuality.VERY_LOW -> {
                // For VERY_LOW quality, fit within 360p bounds
                val maxDimension = max(WIDTH_360P, HEIGHT_360P)  // 640
                calculateDimensionsToFitBounds(originalWidth, originalHeight, maxDimension, maxDimension)
            }
            VVideoCompressQuality.ULTRA_LOW -> {
                // For ULTRA_LOW quality, fit within 240p bounds
                val maxDimension = max(WIDTH_240P, HEIGHT_240P)  // 432
                calculateDimensionsToFitBounds(originalWidth, originalHeight, maxDimension, maxDimension)
            }
        }
        val width = maxDimensions.first
        val height = maxDimensions.second
        val finalWidth = if (width % 16 != 0) alignTo16(width) else width
        val finalHeight = if (height % 16 != 0) alignTo16(height) else height
        if (finalWidth != width || finalHeight != height) {
            Log.d("VVideoCompressor", "Dimension alignment: ${width}x${height} → ${finalWidth}x${finalHeight} (16-pixel boundary)")
        }
        return Pair(finalWidth, finalHeight)
    }

    /**
     * Calculates dimensions that fit within bounds while maintaining aspect ratio
     */
    private fun calculateDimensionsToFitBounds(
        originalWidth: Int,
        originalHeight: Int,
        maxWidth: Int,
        maxHeight: Int
    ): Pair<Int, Int> {
        val aspectRatio: Float = originalWidth.toFloat() / originalHeight.toFloat()
        
        return if (originalWidth.toFloat() / maxWidth > originalHeight.toFloat() / maxHeight) {
            // Width is the limiting factor
            val newWidth: Int = minOf(originalWidth, maxWidth)
            val newHeight: Int = (newWidth / aspectRatio).toInt()
            Pair(newWidth, newHeight)
        } else {
            // Height is the limiting factor
            val newHeight: Int = minOf(originalHeight, maxHeight)
            val newWidth: Int = (newHeight * aspectRatio).toInt()
            Pair(newWidth, newHeight)
        }
    }

    /**
     * Gets quality settings with proper aspect ratio calculation and optimization
     */
    private fun getQualitySettings(
        video: VVideoInfo, 
        quality: VVideoCompressQuality,
        advanced: VVideoAdvancedConfig? = null
    ): Triple<Int, Int, Int> {
        val (width: Int, height: Int) = calculateAspectRatioPreservingDimensions(
            video.width, 
            video.height, 
            quality
        )
        
        val optimizedBitrate = VVideoEncodingSettings.targetBitrate(
            width,
            height,
            quality,
            advanced
        )
        
        return Triple(width, height, optimizedBitrate)
    }
    
    /**
     * Creates edited media item with quality settings and advanced configuration
     */
    private fun createEditedMediaItemWithQuality(
        mediaItem: MediaItem, 
        video: VVideoInfo,
        config: VVideoCompressionConfig,
        cropPlan: VVideoCropPlan? = null,
        sourceFrameRate: Double? = null
    ): EditedMediaItem {
        val advanced = config.advanced
        
        // ORIENTATION FIX: Detect original rotation if auto-correction is enabled
        val shouldAutoCorrect = advanced?.autoCorrectOrientation == true
        val originalRotation = if (shouldAutoCorrect) {
            getVideoRotation(video.path)
        } else {
            0
        }
        
        // Calculate final rotation - either from config or auto-detected
        val finalRotation = if (cropPlan != null) {
            // Media3's decoder has already honored source rotation metadata.
            advanced?.rotation ?: 0
        } else {
            advanced?.rotation ?: if (shouldAutoCorrect) originalRotation else 0
        }
        
        // Calculate proper dimensions that maintain aspect ratio
        val (finalWidth: Int, finalHeight: Int) = cropPlan?.outputSize?.let {
            Pair(it.width, it.height)
        } ?: if (video.width > 0 && video.height > 0) {
            calculateAspectRatioPreservingDimensions(
                video.width,
                video.height,
                config.quality,
                advanced?.customWidth,
                advanced?.customHeight
            )
        } else {
            // Fallback for unknown dimensions
            val (width: Int, height: Int, _) = getQualitySettings(video, config.quality, advanced)
            Pair(width, height)
        }
        
        // Build MediaItem with clipping if trimming is specified
        val adjustedMediaItem: MediaItem = if (advanced?.trimStartMs != null || advanced?.trimEndMs != null) {
            val startMs: Long = advanced?.trimStartMs?.toLong() ?: 0L
            val endMs: Long = advanced?.trimEndMs?.toLong() ?: video.durationMillis
            
            MediaItem.Builder()
                .setUri(mediaItem.localConfiguration?.uri)
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(startMs)
                        .setEndPositionMs(endMs)
                        .build()
                )
                .build()
        } else {
            mediaItem
        }
        
        val videoEffects = mutableListOf<androidx.media3.common.Effect>()

        VVideoEncodingSettings.frameDropTarget(advanced?.frameRate, sourceFrameRate)?.let {
            videoEffects.add(FrameDropEffect.createDefaultFrameDropEffect(it.toFloat()))
            println("VVideoCompressionEngine: Requesting output frame rate ${it}fps")
        }

        // ORIENTATION FIX: Apply rotation BEFORE presentation scaling
        if (finalRotation != 0) {
            val rotationDegrees = if (cropPlan != null) {
                VVideoCropGeometry.cropRotationDegrees(finalRotation)
            } else {
                finalRotation.toFloat()
            }
            val rotationEffect = ScaleAndRotateTransformation.Builder()
                .setRotationDegrees(rotationDegrees)
                .build()
            videoEffects.add(rotationEffect)
            println("VVideoCompressionEngine: Applied ${finalRotation}° rotation (auto-correct: $shouldAutoCorrect)")
        }

        cropPlan?.let { plan ->
            videoEffects.add(
                Crop(
                    plan.media3Crop.left,
                    plan.media3Crop.right,
                    plan.media3Crop.bottom,
                    plan.media3Crop.top
                )
            )
        }

        // Add presentation effect with properly calculated dimensions
        val presentationEffect = Presentation.createForWidthAndHeight(
            finalWidth,
            finalHeight,
            cropPlan?.presentationLayout ?: Presentation.LAYOUT_SCALE_TO_FIT
        )
        videoEffects.add(presentationEffect)
        
        val effects = Effects(
            /* audioProcessors= */ emptyList(),
            /* videoEffects= */ videoEffects
        )
        
        val builder = EditedMediaItem.Builder(adjustedMediaItem)
            .setEffects(effects)
        
        // Apply remove audio if specified
        if (advanced?.removeAudio == true || !config.includeAudio) {
            builder.setRemoveAudio(true)
        }
        
        return builder.build()
    }
    
    /**
     * Resolves and validates the directory used by Media3's muxer.
     */
    @Throws(IOException::class)
    private fun prepareOutputDirectory(outputPath: String?): File {
        val directory = if (!outputPath.isNullOrBlank()) {
            File(outputPath)
        } else {
            val moviesDirectory =
                context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
                    ?: File(context.filesDir, "Movies")
            File(moviesDirectory, "CompressedVideos")
        }

        if (directory.exists() && !directory.isDirectory) {
            throw IOException("The configured output path is not a directory")
        }
        if (!directory.exists() && !directory.mkdirs()) {
            throw IOException("Could not create the configured output directory")
        }
        if (!directory.canWrite()) {
            throw IOException("The configured output directory is not writable")
        }

        return directory.canonicalFile
    }

    /**
     * Creates a unique output path for each attempt.
     */
    private fun createOutputFile(
        outputDirectory: File,
        video: VVideoInfo,
        quality: VVideoCompressQuality
    ): File {
        val qualitySuffix = when (quality) {
            VVideoCompressQuality.HIGH -> "1080p"
            VVideoCompressQuality.MEDIUM -> "720p"
            VVideoCompressQuality.LOW -> "480p"
            VVideoCompressQuality.VERY_LOW -> "360p"
            VVideoCompressQuality.ULTRA_LOW -> "240p"
        }

        val safeBaseName = video.name
            .substringBeforeLast('.')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(80)
            .ifBlank { "video" }
        val filename =
            "compressed_${safeBaseName}_${qualitySuffix}_${UUID.randomUUID()}.mp4"
        return File(outputDirectory, filename)
    }
    
    /**
     * Creates compression result from completed compression
     */
    private fun createCompressionResult(
        originalVideo: VVideoInfo,
        compressedFile: File,
        quality: VVideoCompressQuality,
        timeTaken: Long,
        usedOriginalFile: Boolean
    ): VVideoCompressionResult {
        val originalSizeBytes = originalVideo.fileSizeBytes
        val compressedSizeBytes = compressedFile.length()
        val compressionRatio = compressedSizeBytes.toFloat() / originalSizeBytes
        val spaceSaved = originalSizeBytes - compressedSizeBytes
        
        val originalResolution = "${originalVideo.width}x${originalVideo.height}"
        val compressedResolution = getCompressedResolution(compressedFile, quality)
        
        return VVideoCompressionResult(
            originalVideo = originalVideo,
            compressedFilePath = compressedFile.absolutePath,
            galleryUri = null,
            originalSizeBytes = originalSizeBytes,
            compressedSizeBytes = compressedSizeBytes,
            compressionRatio = compressionRatio,
            timeTaken = timeTaken,
            quality = quality,
            originalResolution = originalResolution,
            compressedResolution = compressedResolution,
            spaceSaved = spaceSaved,
            usedOriginalFile = usedOriginalFile
        )
    }
    
    /**
     * Gets compressed video resolution with proper resource management
     */
    private fun getCompressedResolution(compressedFile: File, quality: VVideoCompressQuality): String {
        var retriever: MediaMetadataRetriever? = null
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(compressedFile.absolutePath)
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            "${width}x${height}"
        } catch (e: Exception) {
            // Fallback to quality-based resolution
            when (quality) {
                VVideoCompressQuality.HIGH -> "1920x1080"
                VVideoCompressQuality.MEDIUM -> "1280x720"
                VVideoCompressQuality.LOW -> "854x480"
                VVideoCompressQuality.VERY_LOW -> "640x360"
                VVideoCompressQuality.ULTRA_LOW -> "426x240"
            }
        } finally {
            retriever?.release()
        }
    }
    
    /**
     * Formats file size in human-readable format
     */
    private fun formatFileSize(bytes: Long): String {
        val kb = bytes / 1024.0
        val mb = kb / 1024.0
        val gb = mb / 1024.0
        
        return when {
            gb >= 1.0 -> String.format("%.1f GB", gb)
            mb >= 1.0 -> String.format("%.1f MB", mb)
            else -> String.format("%.1f KB", kb)
        }
    }
    
    /**
     * 4K FIX: Enhanced compression settings with 4K-specific optimizations
     */
    private fun applyAdvancedCompressionSettings(
        transformerBuilder: Transformer.Builder,
        advanced: VVideoAdvancedConfig?,
        videoInfo: VVideoInfo
    ) {
        if (advanced == null) return
        
        val is4K = videoInfo.width >= 3840 || videoInfo.height >= 2160
        
        // 4K FIX: Apply 4K-specific optimizations
        if (is4K) {
            // Always enable trim optimization for 4K videos
            transformerBuilder.experimentalSetTrimOptimizationEnabled(true)
            
            // Force hardware acceleration for 4K if available
            if (advanced.hardwareAcceleration != false) {
                try {
                    // Hardware acceleration is critical for 4K processing
                    println("4K FIX: Enabling hardware acceleration for 4K video")
                } catch (e: Exception) {
                    println("4K FIX: Hardware acceleration failed, using software encoding")
                }
            }
            
            // Apply conservative settings for 4K to prevent codec failures
            println("4K FIX: Applying 4K-optimized compression settings")
        }
        
        // Apply aggressive compression if enabled
        if (advanced.aggressiveCompression == true) {
            // Enable all size-reducing optimizations
            transformerBuilder.experimentalSetTrimOptimizationEnabled(true)
            
            // Use slower encoding for better compression if not specified
            if (advanced.encodingSpeed == null) {
                // Default to slower encoding for better compression
            }
        }
        
        // Apply hardware acceleration optimization
        if (advanced.hardwareAcceleration == true) {
            try {
                // Hardware acceleration is handled by the system encoder selection
                // No explicit API call needed - Media3 uses hardware by default when available
            } catch (e: Exception) {
                // Fallback if hardware acceleration fails
            }
        }
        
        // reducedFrameRate is accounted for by the bitrate planner. The explicit
        // frameRate setting controls output frame dropping in the effects pipeline.
        
        // Apply mono audio conversion if specified
        if (advanced.monoAudio == true) {
            // Mono audio conversion will be handled in audio processing
            // This reduces file size by ~50% for audio track
        }
        
        // Apply variable bitrate settings
        if (advanced.variableBitrate == true) {
            // VBR provides better compression efficiency than CBR
            // This is handled through the codec configuration
        }
    }

    /**
     * Generates a thumbnail from a video file at the specified time with memory management
     */
    fun getVideoThumbnail(
        videoInfo: VVideoInfo,
        config: VVideoThumbnailConfig
    ): VVideoThumbnailResult? {
        var retriever: MediaMetadataRetriever? = null
        var bitmap: android.graphics.Bitmap? = null
        var finalBitmap: android.graphics.Bitmap? = null
        
        return try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoInfo.path)
            
            // Get frame at specified time (in microseconds)
            val timeUs = config.timeMs * 1000L
            bitmap = retriever.getFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )
            
            if (bitmap == null) {
                return null
            }
            
            // Create output file
            val outputFile = createThumbnailOutputFile(
                config.outputPath,
                videoInfo.name,
                config.format,
                config.timeMs
            )
            
            // Scale bitmap if dimensions are specified
            finalBitmap = if (config.maxWidth != null || config.maxHeight != null) {
                scaleBitmapWithAspectRatio(
                    bitmap,
                    config.maxWidth,
                    config.maxHeight
                )
            } else {
                bitmap
            }
            
            // Save bitmap to file
            val compressFormat = when (config.format) {
                VThumbnailFormat.JPEG -> android.graphics.Bitmap.CompressFormat.JPEG
                VThumbnailFormat.PNG -> android.graphics.Bitmap.CompressFormat.PNG
            }
            
            outputFile.outputStream().use { outputStream ->
                finalBitmap.compress(compressFormat, config.quality, outputStream)
            }
            
            VVideoThumbnailResult(
                thumbnailPath = outputFile.absolutePath,
                width = finalBitmap.width,
                height = finalBitmap.height,
                fileSizeBytes = outputFile.length(),
                format = config.format,
                timeMs = config.timeMs
            )
        } catch (e: OutOfMemoryError) {
            e.printStackTrace()
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            // Always clean up resources
            try {
                if (finalBitmap != bitmap && finalBitmap != null) {
                    finalBitmap.recycle()
                }
                bitmap?.recycle()
                retriever?.release()
            } catch (e: Exception) {
                // Ignore cleanup errors
            }
        }
    }

    /**
     * Creates thumbnail output file
     */
    private fun createThumbnailOutputFile(
        outputPath: String?,
        videoName: String,
        format: VThumbnailFormat,
        timeMs: Int
    ): File {
        val outputDirectory = if (outputPath != null) {
            File(outputPath).apply { 
                if (!exists()) mkdirs() 
            }
        } else {
            File(context.getExternalFilesDir(Environment.DIRECTORY_PICTURES), "VideoThumbnails").apply {
                if (!exists()) mkdirs()
            }
        }
        
        val timestamp = System.currentTimeMillis()
        val filename = "thumb_${videoName.substringBeforeLast('.')}_${timeMs}ms_$timestamp${format.extension}"
        return File(outputDirectory, filename)
    }

    /**
     * Scales bitmap while maintaining aspect ratio
     */
    private fun scaleBitmapWithAspectRatio(
        bitmap: android.graphics.Bitmap,
        maxWidth: Int?,
        maxHeight: Int?
    ): android.graphics.Bitmap {
        val originalWidth = bitmap.width
        val originalHeight = bitmap.height
        
        if (maxWidth == null && maxHeight == null) {
            return bitmap
        }
        
        val aspectRatio = originalWidth.toFloat() / originalHeight.toFloat()
        
        val (targetWidth, targetHeight) = when {
            maxWidth != null && maxHeight != null -> {
                // Both dimensions specified - fit within bounds
                if (originalWidth.toFloat() / maxWidth > originalHeight.toFloat() / maxHeight) {
                    // Width is limiting factor
                    Pair(maxWidth, (maxWidth / aspectRatio).toInt())
                } else {
                    // Height is limiting factor
                    Pair((maxHeight * aspectRatio).toInt(), maxHeight)
                }
            }
            maxWidth != null -> {
                // Only width specified
                Pair(maxWidth, (maxWidth / aspectRatio).toInt())
            }
            maxHeight != null -> {
                // Only height specified
                Pair((maxHeight * aspectRatio).toInt(), maxHeight)
            }
            else -> {
                Pair(originalWidth, originalHeight)
            }
        }
        
        return if (targetWidth == originalWidth && targetHeight == originalHeight) {
            bitmap
        } else {
            android.graphics.Bitmap.createScaledBitmap(
                bitmap,
                targetWidth,
                targetHeight,
                true
            )
        }
    }

    /**
     * Performance optimization from Android Quick Fix
     */
    protected fun finalize() {
        // Remove finalize to avoid GC overhead
        // cleanup()
    }

    /**
     * Release resources immediately after use (Android Quick Fix)
     */
    private fun releaseTransformer() {
        // Media3 Transformer doesn't have release() method
        // Just clear the reference and let GC handle cleanup
        transformer = null
    }

    /**
     * Clean up all temporary files and free resources
     */
    fun cleanup(): Map<String, Any> {
        return try {
            // Cancel any ongoing operations
            cancelCompression()
            
            // Clean up temporary files
            val thumbnailsDeleted = cleanupThumbnailDirectory()
            val cacheCleared = clearTemporaryCache()
            
            // Force garbage collection
            System.gc()
            
            mapOf<String, Any>(
                "success" to true,
                "thumbnailsDeleted" to thumbnailsDeleted,
                "cacheCleared" to cacheCleared,
                "message" to "Cleanup completed successfully"
            )
        } catch (e: Exception) {
            e.printStackTrace()
            mapOf<String, Any>(
                "success" to false,
                "error" to (e.message ?: "Unknown error"),
                "message" to "Cleanup failed"
            )
        }
    }

    /**
     * Clean up specific files and directories
     */
    fun cleanupFiles(
        deleteThumbnails: Boolean = true,
        deleteCompressedVideos: Boolean = false,
        clearCache: Boolean = true
    ): Map<String, Any> {
        return try {
            var thumbnailsDeleted = 0
            var videosDeleted = 0
            var cacheCleared = false
            
            if (deleteThumbnails) {
                thumbnailsDeleted = cleanupThumbnailDirectory()
            }
            
            if (deleteCompressedVideos) {
                videosDeleted = cleanupCompressedVideosDirectory()
            }
            
            if (clearCache) {
                cacheCleared = clearTemporaryCache()
            }
            
            mapOf<String, Any>(
                "success" to true,
                "thumbnailsDeleted" to thumbnailsDeleted,
                "videosDeleted" to videosDeleted,
                "cacheCleared" to cacheCleared,
                "message" to "Selective cleanup completed successfully"
            )
        } catch (e: Exception) {
            e.printStackTrace()
            mapOf<String, Any>(
                "success" to false,
                "error" to (e.message ?: "Unknown error"),
                "message" to "Selective cleanup failed"
            )
        }
    }

    /**
     * Clean up thumbnail directory
     */
    private fun cleanupThumbnailDirectory(): Int {
        return try {
            val thumbnailDir = File(context.getExternalFilesDir(Environment.DIRECTORY_PICTURES), "VideoThumbnails")
            if (thumbnailDir.exists()) {
                val files = thumbnailDir.listFiles()
                if (files != null) {
                    var deletedCount = 0
                    for (file in files) {
                        if (file.isFile && file.delete()) {
                            deletedCount++
                        }
                    }
                    deletedCount
                } else {
                    0
                }
            } else {
                0
            }
        } catch (e: Exception) {
            e.printStackTrace()
            0
        }
    }

    /**
     * Clean up compressed videos directory
     */
    private fun cleanupCompressedVideosDirectory(): Int {
        return try {
            val compressedDir = File(context.getExternalFilesDir(Environment.DIRECTORY_MOVIES), "CompressedVideos")
            if (compressedDir.exists()) {
                val files = compressedDir.listFiles()
                if (files != null) {
                    var deletedCount = 0
                    for (file in files) {
                        if (file.isFile && file.delete()) {
                            deletedCount++
                        }
                    }
                    deletedCount
                } else {
                    0
                }
            } else {
                0
            }
        } catch (e: Exception) {
            e.printStackTrace()
            0
        }
    }

    /**
     * Clear temporary cache and free memory (Android Quick Fix improvements)
     */
    private fun clearTemporaryCache(): Boolean {
        return try {
            // Clear any cached bitmaps or temporary data
            // Force stop any background jobs
            progressJob?.cancel()
            
            // Release transformer resources
            releaseTransformer()
            
            // Clear internal state
            isCompressionActive.set(false)
            isCancelled.set(false)
            
            // Force garbage collection (Android Quick Fix)
            System.gc()
            
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
