/// Video compression models and data classes
library;

/// Dimension alignment handling behavior
enum VDimensionHandling {
  autoAlign(
      'AUTO_ALIGN', 'Auto align dimensions to 16-pixel boundaries when needed'),
  letterbox(
      'LETTERBOX', 'Add black bars to maintain aspect ratio during alignment'),
  exact(
      'EXACT', 'Keep exact dimensions without alignment (may cause artifacts)');

  const VDimensionHandling(this.value, this.description);

  final String value;
  final String description;
}

/// Compression quality levels
enum VVideoCompressQuality {
  high('HIGH', '1080p HD', 'High quality with better file size'),
  medium('MEDIUM', '720p', 'Balanced quality and compression'),
  low('LOW', '480p', 'Good compression for sharing'),
  veryLow('VERY_LOW', '360p', 'High compression, smaller files'),
  ultraLow('ULTRA_LOW', '240p', 'Maximum compression, smallest files');

  const VVideoCompressQuality(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;
}

/// Video codec types
enum VVideoCodec {
  h264('H264', 'H.264/AVC', 'Standard codec, widely compatible'),
  h265('H265', 'H.265/HEVC', 'Better compression, newer devices');

  const VVideoCodec(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;
}

/// Audio codec types
enum VAudioCodec {
  aac('AAC', 'AAC', 'Standard audio codec'),
  mp3('MP3', 'MP3', 'Universal compatibility');

  const VAudioCodec(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;
}

/// Encoding speed vs quality tradeoff
enum VEncodingSpeed {
  ultrafast('ULTRAFAST', 'Ultra Fast', 'Fastest encoding, larger file'),
  superfast('SUPERFAST', 'Super Fast', 'Very fast encoding'),
  veryfast('VERYFAST', 'Very Fast', 'Fast encoding, good for real-time'),
  faster('FASTER', 'Faster', 'Faster than default'),
  fast('FAST', 'Fast', 'Fast encoding'),
  medium('MEDIUM', 'Medium', 'Balanced speed and quality'),
  slow('SLOW', 'Slow', 'Better quality, slower'),
  slower('SLOWER', 'Slower', 'High quality, slow'),
  veryslow('VERYSLOW', 'Very Slow', 'Best quality, very slow');

  const VEncodingSpeed(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;
}

/// Thumbnail output format
enum VThumbnailFormat {
  jpeg('JPEG', 'image/jpeg', '.jpg'),
  png('PNG', 'image/png', '.png');

  const VThumbnailFormat(this.value, this.mimeType, this.extension);

  final String value;
  final String mimeType;
  final String extension;
}

/// Helper function to align dimensions to 16-pixel boundaries
/// Fixes encoder padding artifacts by ensuring dimensions align with encoder requirements
int alignTo16(int dimension) => (dimension ~/ 16) * 16;

/// Compression progress status
enum VVideoCompressionStatus {
  started('STARTED', 'Compression started'),
  progressing('PROGRESSING', 'Compression in progress'),
  completed('COMPLETED', 'Compression completed successfully'),
  failed('FAILED', 'Compression failed'),
  cancelled('CANCELLED', 'Compression cancelled');

  const VVideoCompressionStatus(this.value, this.description);

  final String value;
  final String description;
}

/// A normalized crop rectangle in the correctly displayed video frame.
///
/// Coordinates use the inclusive `0.0..1.0` frame coordinate space after
/// source orientation metadata and the requested discrete rotation are
/// applied. [left] and [top] are the starting edges; [right] and [bottom] are
/// the ending edges.
class VVideoCropRect {
  const VVideoCropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Tolerance used only when detecting the full-frame no-op rectangle.
  static const double fullFrameTolerance = 1e-6;

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Whether every coordinate is finite and the rectangle has positive area
  /// entirely inside the normalized frame.
  bool isValid() {
    return left.isFinite &&
        top.isFinite &&
        right.isFinite &&
        bottom.isFinite &&
        left >= 0.0 &&
        top >= 0.0 &&
        right <= 1.0 &&
        bottom <= 1.0 &&
        left < right &&
        top < bottom;
  }

  /// Whether this valid rectangle selects the complete frame.
  ///
  /// The tolerance avoids treating harmless serialization round-off as an
  /// effective edit. It is not used to clamp or validate coordinates.
  bool isFullFrame() {
    return isValid() &&
        left.abs() <= fullFrameTolerance &&
        top.abs() <= fullFrameTolerance &&
        (right - 1.0).abs() <= fullFrameTolerance &&
        (bottom - 1.0).abs() <= fullFrameTolerance;
  }

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    };
  }

  factory VVideoCropRect.fromMap(Map<String, dynamic> map) {
    double coordinate(String key) {
      final value = map[key];
      if (value is! num) {
        throw ArgumentError.value(
            value, key, 'Crop coordinate must be numeric');
      }
      return value.toDouble();
    }

    return VVideoCropRect(
      left: coordinate('left'),
      top: coordinate('top'),
      right: coordinate('right'),
      bottom: coordinate('bottom'),
    );
  }

  @override
  String toString() {
    return 'VVideoCropRect(left: $left, top: $top, right: $right, bottom: $bottom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VVideoCropRect &&
            left == other.left &&
            top == other.top &&
            right == other.right &&
            bottom == other.bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Advanced video compression configuration
class VVideoAdvancedConfig {
  static const int _maximumNativeBitrate = 0x7fffffff;

  /// Custom video bitrate in bits per second (overrides quality preset).
  ///
  /// Must be between 1 and 2,147,483,647.
  ///
  /// On iOS this is approximated with an export file-length budget, so the
  /// encoded bitrate can vary slightly from the requested value.
  final int? videoBitrate;

  /// Custom audio bitrate in bits per second.
  ///
  /// Must be between 1 and 2,147,483,647.
  ///
  /// AVAssetExportSession selects the audio bitrate on iOS; this remains an
  /// independent encoder setting only on platforms that expose that control.
  final int? audioBitrate;

  /// Custom resolution width (must be used with height)
  final int? customWidth;

  /// Custom resolution height (must be used with width)
  final int? customHeight;

  /// Target frame rate (FPS)
  final double? frameRate;

  /// Video codec selection
  final VVideoCodec? videoCodec;

  /// Audio codec selection
  final VAudioCodec? audioCodec;

  /// Encoding speed vs quality tradeoff
  final VEncodingSpeed? encodingSpeed;

  /// Constant Rate Factor (0-51, lower = better quality)
  final int? crf;

  /// Enable two-pass encoding for better quality
  final bool? twoPassEncoding;

  /// Enable hardware acceleration
  final bool? hardwareAcceleration;

  /// Trim video - start time in milliseconds
  final int? trimStartMs;

  /// Trim video - end time in milliseconds
  final int? trimEndMs;

  /// Rotate video (degrees: 0, 90, 180, 270)
  final int? rotation;

  /// Optional normalized crop in the displayed, explicitly rotated frame.
  final VVideoCropRect? cropRect;

  /// Audio sample rate in Hz
  final int? audioSampleRate;

  /// Audio channels (1 = mono, 2 = stereo)
  final int? audioChannels;

  /// Remove audio track completely
  final bool? removeAudio;

  /// Auto-correct video orientation (preserves original orientation)
  final bool? autoCorrectOrientation;

  /// Video brightness adjustment (-1.0 to 1.0)
  final double? brightness;

  /// Video contrast adjustment (-1.0 to 1.0)
  final double? contrast;

  /// Video saturation adjustment (-1.0 to 1.0)
  final double? saturation;

  /// Enable variable bitrate for better compression efficiency
  final bool? variableBitrate;

  /// Keyframe interval in seconds (larger = better compression)
  final int? keyframeInterval;

  /// Number of B-frames for better encoding efficiency (0-16)
  final int? bFrames;

  /// Automatically reduce frame rate for smaller files
  final double? reducedFrameRate;

  /// Enable all aggressive compression settings
  final bool? aggressiveCompression;

  /// Apply noise reduction preprocessing
  final bool? noiseReduction;

  /// Convert audio to mono for smaller file size
  final bool? monoAudio;

  /// Dimension alignment handling (null = smart auto-detection)
  final VDimensionHandling? dimensionHandling;

  const VVideoAdvancedConfig({
    this.videoBitrate,
    this.audioBitrate,
    this.customWidth,
    this.customHeight,
    this.frameRate,
    this.videoCodec,
    this.audioCodec,
    this.encodingSpeed,
    this.crf,
    this.twoPassEncoding,
    this.hardwareAcceleration,
    this.trimStartMs,
    this.trimEndMs,
    this.rotation,
    this.cropRect,
    this.audioSampleRate,
    this.audioChannels,
    this.removeAudio,
    this.autoCorrectOrientation,
    this.brightness,
    this.contrast,
    this.saturation,
    this.variableBitrate,
    this.keyframeInterval,
    this.bFrames,
    this.reducedFrameRate,
    this.aggressiveCompression,
    this.noiseReduction,
    this.monoAudio,
    this.dimensionHandling,
  });

  /// Validates the advanced configuration
  bool isValid() {
    // Both width and height must be specified together
    if ((customWidth != null) != (customHeight != null)) {
      return false;
    }

    // Resolution must be positive and even numbers
    if (customWidth != null && customHeight != null) {
      if (customWidth! <= 0 ||
          customHeight! <= 0 ||
          customWidth! % 2 != 0 ||
          customHeight! % 2 != 0) {
        return false;
      }
    }

    if (videoBitrate != null &&
        (videoBitrate! <= 0 || videoBitrate! > _maximumNativeBitrate)) {
      return false;
    }

    if (audioBitrate != null &&
        (audioBitrate! <= 0 || audioBitrate! > _maximumNativeBitrate)) {
      return false;
    }

    // Frame rate must be positive
    if (frameRate != null && frameRate! <= 0) {
      return false;
    }

    // CRF must be in valid range
    if (crf != null && (crf! < 0 || crf! > 51)) {
      return false;
    }

    // Rotation must be valid degrees
    if (rotation != null && ![0, 90, 180, 270].contains(rotation!)) {
      return false;
    }

    if (cropRect != null && !cropRect!.isValid()) {
      return false;
    }

    // Trim times must be logical
    if (trimStartMs != null &&
        trimEndMs != null &&
        trimStartMs! >= trimEndMs!) {
      return false;
    }

    // Audio settings validation
    if (audioSampleRate != null && audioSampleRate! <= 0) {
      return false;
    }

    if (audioChannels != null && (audioChannels! < 1 || audioChannels! > 8)) {
      return false;
    }

    // Color adjustments must be in range
    if (brightness != null && (brightness! < -1.0 || brightness! > 1.0)) {
      return false;
    }

    if (contrast != null && (contrast! < -1.0 || contrast! > 1.0)) {
      return false;
    }

    if (saturation != null && (saturation! < -1.0 || saturation! > 1.0)) {
      return false;
    }

    // Validate compression options
    if (keyframeInterval != null &&
        (keyframeInterval! < 1 || keyframeInterval! > 30)) {
      return false;
    }

    if (bFrames != null && (bFrames! < 0 || bFrames! > 16)) {
      return false;
    }

    if (reducedFrameRate != null &&
        (reducedFrameRate! <= 0 || reducedFrameRate! > 120)) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'videoBitrate': videoBitrate,
      'audioBitrate': audioBitrate,
      'customWidth': customWidth,
      'customHeight': customHeight,
      'frameRate': frameRate,
      'videoCodec': videoCodec?.value,
      'audioCodec': audioCodec?.value,
      'encodingSpeed': encodingSpeed?.value,
      'crf': crf,
      'twoPassEncoding': twoPassEncoding,
      'hardwareAcceleration': hardwareAcceleration,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
      'rotation': rotation,
      'audioSampleRate': audioSampleRate,
      'audioChannels': audioChannels,
      'removeAudio': removeAudio,
      'autoCorrectOrientation': autoCorrectOrientation,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'variableBitrate': variableBitrate,
      'keyframeInterval': keyframeInterval,
      'bFrames': bFrames,
      'reducedFrameRate': reducedFrameRate,
      'aggressiveCompression': aggressiveCompression,
      'noiseReduction': noiseReduction,
      'monoAudio': monoAudio,
      'dimensionHandling': dimensionHandling?.value,
    };
    if (cropRect != null) {
      map['cropRect'] = cropRect!.toMap();
    }
    return map;
  }

  factory VVideoAdvancedConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return VVideoAdvancedConfig();

    return VVideoAdvancedConfig(
      videoBitrate: map['videoBitrate']?.toInt(),
      audioBitrate: map['audioBitrate']?.toInt(),
      customWidth: map['customWidth']?.toInt(),
      customHeight: map['customHeight']?.toInt(),
      frameRate: map['frameRate']?.toDouble(),
      videoCodec: VVideoCodec.values.cast<VVideoCodec?>().firstWhere(
            (codec) => codec?.value == map['videoCodec'],
            orElse: () => null,
          ),
      audioCodec: VAudioCodec.values.cast<VAudioCodec?>().firstWhere(
            (codec) => codec?.value == map['audioCodec'],
            orElse: () => null,
          ),
      encodingSpeed: VEncodingSpeed.values.cast<VEncodingSpeed?>().firstWhere(
            (speed) => speed?.value == map['encodingSpeed'],
            orElse: () => null,
          ),
      crf: map['crf']?.toInt(),
      twoPassEncoding: map['twoPassEncoding'],
      hardwareAcceleration: map['hardwareAcceleration'],
      trimStartMs: map['trimStartMs']?.toInt(),
      trimEndMs: map['trimEndMs']?.toInt(),
      rotation: map['rotation']?.toInt(),
      cropRect: map['cropRect'] is Map
          ? VVideoCropRect.fromMap(
              Map<String, dynamic>.from(map['cropRect'] as Map),
            )
          : null,
      audioSampleRate: map['audioSampleRate']?.toInt(),
      audioChannels: map['audioChannels']?.toInt(),
      removeAudio: map['removeAudio'],
      autoCorrectOrientation: map['autoCorrectOrientation'],
      brightness: map['brightness']?.toDouble(),
      contrast: map['contrast']?.toDouble(),
      saturation: map['saturation']?.toDouble(),
      variableBitrate: map['variableBitrate'],
      keyframeInterval: map['keyframeInterval']?.toInt(),
      bFrames: map['bFrames']?.toInt(),
      reducedFrameRate: map['reducedFrameRate']?.toDouble(),
      aggressiveCompression: map['aggressiveCompression'],
      noiseReduction: map['noiseReduction'],
      monoAudio: map['monoAudio'],
      dimensionHandling:
          VDimensionHandling.values.cast<VDimensionHandling?>().firstWhere(
                (handling) => handling?.value == map['dimensionHandling'],
                orElse: () => null,
              ),
    );
  }

  /// Creates a maximum compression configuration for smallest file sizes
  factory VVideoAdvancedConfig.maximumCompression({
    int? targetBitrate,
    bool keepAudio = false,
  }) {
    return VVideoAdvancedConfig(
      videoCodec: VVideoCodec.h265,
      videoBitrate: targetBitrate ?? 300000,
      audioBitrate: keepAudio ? 64000 : null,
      removeAudio: !keepAudio,
      crf: 28,
      twoPassEncoding: true,
      hardwareAcceleration: true,
      variableBitrate: true,
      keyframeInterval: 10,
      bFrames: 3,
      reducedFrameRate: 24.0,
      aggressiveCompression: true,
      noiseReduction: true,
      monoAudio: !keepAudio ? null : true,
      audioSampleRate: keepAudio ? 22050 : null,
      audioChannels: keepAudio ? 1 : null,
      autoCorrectOrientation: true,
      dimensionHandling: VDimensionHandling.autoAlign,
    );
  }

  /// Creates a social media optimized compression configuration
  factory VVideoAdvancedConfig.socialMediaOptimized() {
    return VVideoAdvancedConfig(
      videoCodec: VVideoCodec.h265,
      videoBitrate: 800000,
      audioBitrate: 96000,
      crf: 25,
      variableBitrate: true,
      keyframeInterval: 5,
      bFrames: 2,
      reducedFrameRate: 30.0,
      aggressiveCompression: true,
      audioSampleRate: 44100,
      audioChannels: 2,
      autoCorrectOrientation: true,
      dimensionHandling: VDimensionHandling.autoAlign,
    );
  }

  /// Creates a mobile optimized compression configuration
  factory VVideoAdvancedConfig.mobileOptimized() {
    return VVideoAdvancedConfig(
      videoCodec: VVideoCodec.h264,
      videoBitrate: 1500000,
      audioBitrate: 128000,
      crf: 23,
      hardwareAcceleration: true,
      variableBitrate: true,
      keyframeInterval: 3,
      bFrames: 1,
      reducedFrameRate: 30.0,
      audioSampleRate: 44100,
      audioChannels: 2,
      autoCorrectOrientation: true,
      dimensionHandling: VDimensionHandling.autoAlign,
    );
  }
}

/// Video information model
class VVideoInfo {
  final String path;
  final String name;
  final int fileSizeBytes;
  final int durationMillis;
  final int width;
  final int height;
  final String? thumbnailPath;

  const VVideoInfo({
    required this.path,
    required this.name,
    required this.fileSizeBytes,
    required this.durationMillis,
    required this.width,
    required this.height,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'fileSizeBytes': fileSizeBytes,
      'durationMillis': durationMillis,
      'width': width,
      'height': height,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory VVideoInfo.fromMap(Map<String, dynamic> map) {
    return VVideoInfo(
      path: map['path'] ?? '',
      name: map['name'] ?? '',
      fileSizeBytes: map['fileSizeBytes']?.toInt() ?? 0,
      durationMillis: map['durationMillis']?.toInt() ?? 0,
      width: map['width']?.toInt() ?? 0,
      height: map['height']?.toInt() ?? 0,
      thumbnailPath: map['thumbnailPath'],
    );
  }

  double get fileSizeMB => fileSizeBytes / (1024.0 * 1024.0);

  String get durationFormatted {
    final totalSeconds = durationMillis ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get fileSizeFormatted {
    const kb = 1024.0;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (fileSizeBytes >= gb) {
      return '${(fileSizeBytes / gb).toStringAsFixed(1)} GB';
    } else if (fileSizeBytes >= mb) {
      return '${(fileSizeBytes / mb).toStringAsFixed(1)} MB';
    } else if (fileSizeBytes >= kb) {
      return '${(fileSizeBytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$fileSizeBytes B';
    }
  }
}

/// Configuration for video compression operations
class VVideoCompressionConfig {
  /// Quality level for the compressed video
  final VVideoCompressQuality quality;

  /// Custom output path for the compressed video (optional)
  final String? outputPath;

  /// Whether to delete the original video file after compression
  final bool deleteOriginal;

  /// Whether to return the original file when compression saves less than 5%.
  ///
  /// Set this to `false` when the output codec or container must be guaranteed,
  /// even if the compressed file is not smaller.
  final bool fallbackToOriginalIfNotSmaller;

  /// Whether to save the compressed video to gallery
  final bool saveToGallery;

  /// Whether to include audio in the compressed video
  final bool includeAudio;

  /// Whether to include metadata in the compressed video
  final bool includeMetadata;

  /// Whether to optimize for streaming
  final bool optimizeForStreaming;

  /// Whether to copy metadata from original video
  final bool copyMetadata;

  /// Whether to use hardware acceleration
  final bool useHardwareAcceleration;

  /// Whether to use fast start
  final bool useFastStart;

  /// Whether to use two pass encoding
  final bool useTwoPassEncoding;

  /// Whether to use variable bitrate
  final bool useVariableBitrate;

  /// Advanced compression settings (optional)
  final VVideoAdvancedConfig? advanced;

  const VVideoCompressionConfig({
    required this.quality,
    this.outputPath,
    this.deleteOriginal = false,
    this.fallbackToOriginalIfNotSmaller = true,
    this.saveToGallery = false,
    this.includeAudio = true,
    this.includeMetadata = true,
    this.optimizeForStreaming = true,
    this.copyMetadata = true,
    this.useHardwareAcceleration = true,
    this.useFastStart = true,
    this.useTwoPassEncoding = false,
    this.useVariableBitrate = true,
    this.advanced,
  });

  const VVideoCompressionConfig.high({
    this.outputPath,
    this.deleteOriginal = false,
    this.fallbackToOriginalIfNotSmaller = true,
    this.saveToGallery = false,
    this.includeAudio = true,
    this.includeMetadata = true,
    this.optimizeForStreaming = true,
    this.copyMetadata = true,
    this.useHardwareAcceleration = true,
    this.useFastStart = true,
    this.useTwoPassEncoding = false,
    this.useVariableBitrate = true,
    this.advanced,
  }) : quality = VVideoCompressQuality.high;

  const VVideoCompressionConfig.medium({
    this.outputPath,
    this.deleteOriginal = false,
    this.fallbackToOriginalIfNotSmaller = true,
    this.saveToGallery = false,
    this.includeAudio = true,
    this.includeMetadata = true,
    this.optimizeForStreaming = true,
    this.copyMetadata = true,
    this.useHardwareAcceleration = true,
    this.useFastStart = true,
    this.useTwoPassEncoding = false,
    this.useVariableBitrate = true,
    this.advanced,
  }) : quality = VVideoCompressQuality.medium;

  const VVideoCompressionConfig.low({
    this.outputPath,
    this.deleteOriginal = false,
    this.fallbackToOriginalIfNotSmaller = true,
    this.saveToGallery = false,
    this.includeAudio = true,
    this.includeMetadata = true,
    this.optimizeForStreaming = true,
    this.copyMetadata = true,
    this.useHardwareAcceleration = true,
    this.useFastStart = true,
    this.useTwoPassEncoding = false,
    this.useVariableBitrate = true,
    this.advanced,
  }) : quality = VVideoCompressQuality.low;

  /// Validates the configuration
  bool isValid() {
    if (advanced != null && !advanced!.isValid()) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'quality': quality.value,
      'outputPath': outputPath,
      'deleteOriginal': deleteOriginal,
      'fallbackToOriginalIfNotSmaller': fallbackToOriginalIfNotSmaller,
      'saveToGallery': saveToGallery,
      'includeAudio': includeAudio,
      'includeMetadata': includeMetadata,
      'optimizeForStreaming': optimizeForStreaming,
      'copyMetadata': copyMetadata,
      'useHardwareAcceleration': useHardwareAcceleration,
      'useFastStart': useFastStart,
      'useTwoPassEncoding': useTwoPassEncoding,
      'useVariableBitrate': useVariableBitrate,
      'advanced': advanced?.toMap(),
    };
  }

  factory VVideoCompressionConfig.fromMap(Map<String, dynamic> map) {
    return VVideoCompressionConfig(
      quality: VVideoCompressQuality.values.firstWhere(
        (q) => q.value == map['quality'],
        orElse: () => VVideoCompressQuality.medium,
      ),
      outputPath: map['outputPath'],
      deleteOriginal: map['deleteOriginal'] ?? false,
      fallbackToOriginalIfNotSmaller:
          map['fallbackToOriginalIfNotSmaller'] ?? true,
      saveToGallery: map['saveToGallery'] ?? false,
      includeAudio: map['includeAudio'] ?? true,
      includeMetadata: map['includeMetadata'] ?? true,
      optimizeForStreaming: map['optimizeForStreaming'] ?? true,
      copyMetadata: map['copyMetadata'] ?? true,
      useHardwareAcceleration: map['useHardwareAcceleration'] ?? true,
      useFastStart: map['useFastStart'] ?? true,
      useTwoPassEncoding: map['useTwoPassEncoding'] ?? false,
      useVariableBitrate: map['useVariableBitrate'] ?? true,
      advanced: map['advanced'] != null
          ? VVideoAdvancedConfig.fromMap(map['advanced'])
          : null,
    );
  }

  @override
  String toString() {
    return 'VVideoCompressionConfig(quality: $quality, outputPath: $outputPath, deleteOriginal: $deleteOriginal, fallbackToOriginalIfNotSmaller: $fallbackToOriginalIfNotSmaller, saveToGallery: $saveToGallery, includeAudio: $includeAudio, includeMetadata: $includeMetadata, optimizeForStreaming: $optimizeForStreaming, copyMetadata: $copyMetadata, useHardwareAcceleration: $useHardwareAcceleration, useFastStart: $useFastStart, useTwoPassEncoding: $useTwoPassEncoding, useVariableBitrate: $useVariableBitrate, advanced: $advanced)';
  }
}

/// Compression estimation result
class VVideoCompressionEstimate {
  final int estimatedSizeBytes;
  final String estimatedSizeFormatted;
  final double compressionRatio;
  final double bitrateMbps;

  const VVideoCompressionEstimate({
    required this.estimatedSizeBytes,
    required this.estimatedSizeFormatted,
    required this.compressionRatio,
    required this.bitrateMbps,
  });

  factory VVideoCompressionEstimate.fromMap(Map<String, dynamic> map) {
    return VVideoCompressionEstimate(
      estimatedSizeBytes: map['estimatedSizeBytes']?.toInt() ?? 0,
      estimatedSizeFormatted: map['estimatedSizeFormatted'] ?? '',
      compressionRatio: map['compressionRatio']?.toDouble() ?? 0.0,
      bitrateMbps: map['bitrateMbps']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'estimatedSizeBytes': estimatedSizeBytes,
      'estimatedSizeFormatted': estimatedSizeFormatted,
      'compressionRatio': compressionRatio,
      'bitrateMbps': bitrateMbps,
    };
  }
}

/// Compression result
class VVideoCompressionResult {
  final VVideoInfo originalVideo;
  final String compressedFilePath;
  final String? galleryUri;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final double compressionRatio;
  final int timeTaken;
  final VVideoCompressQuality quality;
  final String originalResolution;
  final String compressedResolution;
  final int spaceSaved;

  /// Whether the original input file was returned instead of the encoded file.
  final bool usedOriginalFile;

  const VVideoCompressionResult({
    required this.originalVideo,
    required this.compressedFilePath,
    this.galleryUri,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.compressionRatio,
    required this.timeTaken,
    required this.quality,
    required this.originalResolution,
    required this.compressedResolution,
    required this.spaceSaved,
    this.usedOriginalFile = false,
  });

  factory VVideoCompressionResult.fromMap(Map<String, dynamic> map) {
    return VVideoCompressionResult(
      originalVideo: VVideoInfo.fromMap(map['originalVideo']),
      compressedFilePath: map['compressedFilePath'] ?? '',
      galleryUri: map['galleryUri'],
      originalSizeBytes: map['originalSizeBytes']?.toInt() ?? 0,
      compressedSizeBytes: map['compressedSizeBytes']?.toInt() ?? 0,
      compressionRatio: map['compressionRatio']?.toDouble() ?? 0.0,
      timeTaken: map['timeTaken']?.toInt() ?? 0,
      quality: VVideoCompressQuality.values.firstWhere(
        (q) => q.value == map['quality'],
        orElse: () => VVideoCompressQuality.medium,
      ),
      originalResolution: map['originalResolution'] ?? '',
      compressedResolution: map['compressedResolution'] ?? '',
      spaceSaved: map['spaceSaved']?.toInt() ?? 0,
      usedOriginalFile: map['usedOriginalFile'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalVideo': originalVideo.toMap(),
      'compressedFilePath': compressedFilePath,
      'galleryUri': galleryUri,
      'originalSizeBytes': originalSizeBytes,
      'compressedSizeBytes': compressedSizeBytes,
      'compressionRatio': compressionRatio,
      'timeTaken': timeTaken,
      'quality': quality.value,
      'originalResolution': originalResolution,
      'compressedResolution': compressedResolution,
      'spaceSaved': spaceSaved,
      'usedOriginalFile': usedOriginalFile,
    };
  }

  String get spaceSavedFormatted => _formatFileSize(spaceSaved);
  int get compressionPercentage => ((1 - compressionRatio) * 100).round();
  String get originalSizeFormatted => _formatFileSize(originalSizeBytes);
  String get compressedSizeFormatted => _formatFileSize(compressedSizeBytes);
  String get timeTakenFormatted => _formatTime(timeTaken);

  String _formatFileSize(int bytes) {
    const kb = 1024.0;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  String _formatTime(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// Video thumbnail configuration
class VVideoThumbnailConfig {
  /// The timestamp in milliseconds to extract the thumbnail from
  final int timeMs;

  /// The maximum width of the thumbnail (maintains aspect ratio)
  final int? maxWidth;

  /// The maximum height of the thumbnail (maintains aspect ratio)
  final int? maxHeight;

  /// The output format for the thumbnail
  final VThumbnailFormat format;

  /// The quality of the thumbnail (0-100, only applies to JPEG)
  final int quality;

  /// The output path for the thumbnail (if null, generates in temp directory)
  final String? outputPath;

  const VVideoThumbnailConfig({
    this.timeMs = 0,
    this.maxWidth,
    this.maxHeight,
    this.format = VThumbnailFormat.jpeg,
    this.quality = 80,
    this.outputPath,
  });

  /// Creates a default configuration for generating thumbnails
  const VVideoThumbnailConfig.defaults({
    this.timeMs = 0,
    this.maxWidth = 200,
    this.maxHeight = 200,
    this.format = VThumbnailFormat.jpeg,
    this.quality = 80,
    this.outputPath,
  });

  /// Validates the thumbnail configuration
  bool isValid() {
    if (timeMs < 0) return false;
    if (maxWidth != null && maxWidth! <= 0) return false;
    if (maxHeight != null && maxHeight! <= 0) return false;
    if (quality < 0 || quality > 100) return false;
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'timeMs': timeMs,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'format': format.value,
      'quality': quality,
      'outputPath': outputPath,
    };
  }

  factory VVideoThumbnailConfig.fromMap(Map<String, dynamic> map) {
    return VVideoThumbnailConfig(
      timeMs: map['timeMs']?.toInt() ?? 0,
      maxWidth: map['maxWidth']?.toInt(),
      maxHeight: map['maxHeight']?.toInt(),
      format: VThumbnailFormat.values.firstWhere(
        (f) => f.value == map['format'],
        orElse: () => VThumbnailFormat.jpeg,
      ),
      quality: map['quality']?.toInt() ?? 80,
      outputPath: map['outputPath'] as String?,
    );
  }
}

/// Video thumbnail result
class VVideoThumbnailResult {
  /// The path to the generated thumbnail file
  final String thumbnailPath;

  /// The width of the generated thumbnail
  final int width;

  /// The height of the generated thumbnail
  final int height;

  /// The file size of the thumbnail in bytes
  final int fileSizeBytes;

  /// The format of the generated thumbnail
  final VThumbnailFormat format;

  /// The timestamp in milliseconds where the thumbnail was extracted from
  final int timeMs;

  const VVideoThumbnailResult({
    required this.thumbnailPath,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.format,
    required this.timeMs,
  });

  factory VVideoThumbnailResult.fromMap(Map<String, dynamic> map) {
    return VVideoThumbnailResult(
      thumbnailPath: map['thumbnailPath'] ?? '',
      width: map['width']?.toInt() ?? 0,
      height: map['height']?.toInt() ?? 0,
      fileSizeBytes: map['fileSizeBytes']?.toInt() ?? 0,
      format: VThumbnailFormat.values.firstWhere(
        (f) => f.value == map['format'],
        orElse: () => VThumbnailFormat.jpeg,
      ),
      timeMs: map['timeMs']?.toInt() ?? 0,
    );
  }

  String get fileSizeFormatted {
    const kb = 1024.0;
    const mb = kb * 1024;

    if (fileSizeBytes >= mb) {
      return '${(fileSizeBytes / mb).toStringAsFixed(1)} MB';
    } else if (fileSizeBytes >= kb) {
      return '${(fileSizeBytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$fileSizeBytes B';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'thumbnailPath': thumbnailPath,
      'width': width,
      'height': height,
      'fileSizeBytes': fileSizeBytes,
      'format': format.value,
      'timeMs': timeMs,
    };
  }
}

/// Typed model for video compression progress events
class VVideoProgressEvent {
  /// Progress value from 0.0 to 1.0
  final double progress;

  /// Optional video path being processed
  final String? videoPath;

  /// Optional current video index for batch operations
  final int? currentIndex;

  /// Optional total number of videos for batch operations
  final int? total;

  /// Optional compression ID for tracking specific operations
  final String? compressionId;

  const VVideoProgressEvent({
    required this.progress,
    this.videoPath,
    this.currentIndex,
    this.total,
    this.compressionId,
  });

  /// Create from native platform data
  factory VVideoProgressEvent.fromMap(Map<String, dynamic> map) {
    return VVideoProgressEvent(
      progress: (map['progress'] as num).toDouble(),
      videoPath: map['videoPath'] as String?,
      currentIndex: map['currentIndex'] as int?,
      total: map['total'] as int?,
      compressionId: map['compressionId'] as String?,
    );
  }

  /// Convert to map for native platform
  Map<String, dynamic> toMap() {
    return {
      'progress': progress,
      if (videoPath != null) 'videoPath': videoPath,
      if (currentIndex != null) 'currentIndex': currentIndex,
      if (total != null) 'total': total,
      if (compressionId != null) 'compressionId': compressionId,
    };
  }

  /// Progress as percentage (0-100)
  double get progressPercentage => progress * 100;

  /// Whether this is a batch operation
  bool get isBatchOperation => currentIndex != null && total != null;

  /// Formatted progress string
  String get progressFormatted => '${progressPercentage.toStringAsFixed(1)}%';

  /// Batch progress description
  String get batchProgressDescription {
    if (!isBatchOperation) return progressFormatted;
    return 'Video ${currentIndex! + 1}/${total!} - $progressFormatted';
  }

  @override
  String toString() {
    return 'VVideoProgressEvent(progress: $progress, videoPath: $videoPath, '
        'currentIndex: $currentIndex, total: $total, compressionId: $compressionId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VVideoProgressEvent &&
        other.progress == progress &&
        other.videoPath == videoPath &&
        other.currentIndex == currentIndex &&
        other.total == total &&
        other.compressionId == compressionId;
  }

  @override
  int get hashCode {
    return progress.hashCode ^
        videoPath.hashCode ^
        currentIndex.hashCode ^
        total.hashCode ^
        compressionId.hashCode;
  }
}
