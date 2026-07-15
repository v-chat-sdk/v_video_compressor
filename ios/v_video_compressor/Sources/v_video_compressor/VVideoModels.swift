import Foundation
import AVFoundation

// MARK: - Compression Quality Levels

enum VVideoCompressQuality: String, CaseIterable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case veryLow = "VERY_LOW"
    case ultraLow = "ULTRA_LOW"
    
    var displayName: String {
        switch self {
        case .high: return "1080p HD"
        case .medium: return "720p"
        case .low: return "480p"
        case .veryLow: return "360p"
        case .ultraLow: return "240p"
        }
    }
    
    var description: String {
        switch self {
        case .high: return "High quality with better file size"
        case .medium: return "Balanced quality and compression"
        case .low: return "Good compression for sharing"
        case .veryLow: return "High compression, smaller files"
        case .ultraLow: return "Maximum compression, smallest files"
        }
    }
    
    static func fromString(_ value: String?) -> VVideoCompressQuality {
        guard let value = value else { return .medium }
        return VVideoCompressQuality(rawValue: value) ?? .medium
    }
}

// MARK: - Video Codec Types

enum VVideoCodec: String, CaseIterable {
    case h264 = "H264"
    case h265 = "H265"
    
    static func fromString(_ value: String?) -> VVideoCodec? {
        guard let value = value else { return nil }
        return VVideoCodec(rawValue: value)
    }
}

// MARK: - Audio Codec Types

enum VAudioCodec: String, CaseIterable {
    case aac = "AAC"
    case mp3 = "MP3"
    
    static func fromString(_ value: String?) -> VAudioCodec? {
        guard let value = value else { return nil }
        return VAudioCodec(rawValue: value)
    }
}

// MARK: - Encoding Speed Types

enum VEncodingSpeed: String, CaseIterable {
    case ultrafast = "ULTRAFAST"
    case superfast = "SUPERFAST"
    case veryfast = "VERYFAST"
    case faster = "FASTER"
    case fast = "FAST"
    case medium = "MEDIUM"
    case slow = "SLOW"
    case slower = "SLOWER"
    case veryslow = "VERYSLOW"
    
    static func fromString(_ value: String?) -> VEncodingSpeed? {
        guard let value = value else { return nil }
        return VEncodingSpeed(rawValue: value)
    }
}

// MARK: - Advanced Video Compression Configuration

struct VVideoAdvancedConfig {
    let videoBitrate: Int?
    let audioBitrate: Int?
    let customWidth: Int?
    let customHeight: Int?
    let frameRate: Double?
    let videoCodec: VVideoCodec?
    let audioCodec: VAudioCodec?
    let encodingSpeed: VEncodingSpeed?
    let crf: Int?
    let twoPassEncoding: Bool?
    let hardwareAcceleration: Bool?
    let trimStartMs: Int?
    let trimEndMs: Int?
    let rotation: Int?
    let audioSampleRate: Int?
    let audioChannels: Int?
    let removeAudio: Bool?
    let autoCorrectOrientation: Bool?
    let brightness: Double?
    let contrast: Double?
    let saturation: Double?
    let variableBitrate: Bool?
    let keyframeInterval: Int?
    let bFrames: Int?
    let reducedFrameRate: Double?
    let aggressiveCompression: Bool?
    let noiseReduction: Bool?
    let monoAudio: Bool?
    
    static func fromMap(_ map: [String: Any]?) -> VVideoAdvancedConfig? {
        guard let map = map else { return nil }
        
        return VVideoAdvancedConfig(
            videoBitrate: map["videoBitrate"] as? Int,
            audioBitrate: map["audioBitrate"] as? Int,
            customWidth: map["customWidth"] as? Int,
            customHeight: map["customHeight"] as? Int,
            frameRate: map["frameRate"] as? Double,
            videoCodec: VVideoCodec.fromString(map["videoCodec"] as? String),
            audioCodec: VAudioCodec.fromString(map["audioCodec"] as? String),
            encodingSpeed: VEncodingSpeed.fromString(map["encodingSpeed"] as? String),
            crf: map["crf"] as? Int,
            twoPassEncoding: map["twoPassEncoding"] as? Bool,
            hardwareAcceleration: map["hardwareAcceleration"] as? Bool,
            trimStartMs: map["trimStartMs"] as? Int,
            trimEndMs: map["trimEndMs"] as? Int,
            rotation: map["rotation"] as? Int,
            audioSampleRate: map["audioSampleRate"] as? Int,
            audioChannels: map["audioChannels"] as? Int,
            removeAudio: map["removeAudio"] as? Bool,
            autoCorrectOrientation: map["autoCorrectOrientation"] as? Bool,
            brightness: map["brightness"] as? Double,
            contrast: map["contrast"] as? Double,
            saturation: map["saturation"] as? Double,
            variableBitrate: map["variableBitrate"] as? Bool,
            keyframeInterval: map["keyframeInterval"] as? Int,
            bFrames: map["bFrames"] as? Int,
            reducedFrameRate: map["reducedFrameRate"] as? Double,
            aggressiveCompression: map["aggressiveCompression"] as? Bool,
            noiseReduction: map["noiseReduction"] as? Bool,
            monoAudio: map["monoAudio"] as? Bool
        )
    }
}

// MARK: - Video Information Model

struct VVideoInfo {
    let path: String
    let name: String
    let fileSizeBytes: Int64
    let durationMillis: Int64
    let width: Int
    let height: Int
    let thumbnailPath: String?
    
    var fileSizeMB: Double {
        return Double(fileSizeBytes) / (1024.0 * 1024.0)
    }
    
    var durationFormatted: String {
        return formatDuration(durationMillis)
    }
    
    var fileSizeFormatted: String {
        return formatFileSize(fileSizeBytes)
    }
    
    private func formatDuration(_ durationMs: Int64) -> String {
        let totalSeconds = durationMs / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }
    
    func toMap() -> [String: Any?] {
        return [
            "path": path,
            "name": name,
            "fileSizeBytes": fileSizeBytes,
            "durationMillis": durationMillis,
            "width": width,
            "height": height,
            "thumbnailPath": thumbnailPath
        ]
    }
    
    static func fromMap(_ map: [String: Any]) -> VVideoInfo {
        return VVideoInfo(
            path: map["path"] as? String ?? "",
            name: map["name"] as? String ?? "",
            fileSizeBytes: (map["fileSizeBytes"] as? NSNumber)?.int64Value ?? 0,
            durationMillis: (map["durationMillis"] as? NSNumber)?.int64Value ?? 0,
            width: map["width"] as? Int ?? 0,
            height: map["height"] as? Int ?? 0,
            thumbnailPath: map["thumbnailPath"] as? String
        )
    }
}

// MARK: - Compression Configuration

struct VVideoCompressionConfig {
    let quality: VVideoCompressQuality
    let outputPath: String?
    let deleteOriginal: Bool
    let advanced: VVideoAdvancedConfig?
    
    static func fromMap(_ map: [String: Any]) -> VVideoCompressionConfig {
        return VVideoCompressionConfig(
            quality: VVideoCompressQuality.fromString(map["quality"] as? String),
            outputPath: map["outputPath"] as? String,
            deleteOriginal: map["deleteOriginal"] as? Bool ?? false,
            advanced: VVideoAdvancedConfig.fromMap(map["advanced"] as? [String: Any])
        )
    }
}

// MARK: - Compression Estimation Result

struct VVideoCompressionEstimate {
    let estimatedSizeBytes: Int64
    let estimatedSizeFormatted: String
    let compressionRatio: Float
    let bitrateMbps: Float
    
    func toMap() -> [String: Any] {
        return [
            "estimatedSizeBytes": estimatedSizeBytes,
            "estimatedSizeFormatted": estimatedSizeFormatted,
            "compressionRatio": compressionRatio,
            "bitrateMbps": bitrateMbps
        ]
    }
}

// MARK: - Compression Result

struct VVideoCompressionResult {
    let originalVideo: VVideoInfo
    let compressedFilePath: String
    let galleryUri: String?
    let originalSizeBytes: Int64
    let compressedSizeBytes: Int64
    let compressionRatio: Float
    let timeTaken: Int64
    let quality: VVideoCompressQuality
    let originalResolution: String
    let compressedResolution: String
    let spaceSaved: Int64
    
    var spaceSavedFormatted: String {
        return formatFileSize(spaceSaved)
    }
    
    var compressionPercentage: Int {
        return Int((1 - compressionRatio) * 100)
    }
    
    var originalSizeFormatted: String {
        return formatFileSize(originalSizeBytes)
    }
    
    var compressedSizeFormatted: String {
        return formatFileSize(compressedSizeBytes)
    }
    
    var timeTakenFormatted: String {
        return formatTime(timeTaken)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.1f KB", kb)
        }
    }
    
    private func formatTime(_ milliseconds: Int64) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    func toMap() -> [String: Any?] {
        return [
            "originalVideo": originalVideo.toMap(),
            "compressedFilePath": compressedFilePath,
            "galleryUri": galleryUri,
            "originalSizeBytes": originalSizeBytes,
            "compressedSizeBytes": compressedSizeBytes,
            "compressionRatio": compressionRatio,
            "timeTaken": timeTaken,
            "quality": quality.rawValue,
            "originalResolution": originalResolution,
            "compressedResolution": compressedResolution,
            "spaceSaved": spaceSaved
        ]
    }
}

// MARK: - Thumbnail Output Format

enum VThumbnailFormat: String, CaseIterable {
    case jpeg = "JPEG"
    case png = "PNG"
    
    var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return ".jpg"
        case .png: return ".png"
        }
    }
    
    static func fromString(_ value: String?) -> VThumbnailFormat {
        guard let value = value else { return .jpeg }
        return VThumbnailFormat(rawValue: value) ?? .jpeg
    }
}

// MARK: - Video Thumbnail Configuration

struct VVideoThumbnailConfig {
    let timeMs: Int
    let maxWidth: Int?
    let maxHeight: Int?
    let format: VThumbnailFormat
    let quality: Int
    let outputPath: String?
    
    func isValid() -> Bool {
        if timeMs < 0 { return false }
        if let maxWidth = maxWidth, maxWidth <= 0 { return false }
        if let maxHeight = maxHeight, maxHeight <= 0 { return false }
        if quality < 0 || quality > 100 { return false }
        return true
    }
    
    static func fromMap(_ map: [String: Any]) -> VVideoThumbnailConfig {
        return VVideoThumbnailConfig(
            timeMs: map["timeMs"] as? Int ?? 0,
            maxWidth: map["maxWidth"] as? Int,
            maxHeight: map["maxHeight"] as? Int,
            format: VThumbnailFormat.fromString(map["format"] as? String),
            quality: map["quality"] as? Int ?? 80,
            outputPath: map["outputPath"] as? String
        )
    }
}

// MARK: - Video Thumbnail Result

struct VVideoThumbnailResult {
    let thumbnailPath: String
    let width: Int
    let height: Int
    let fileSizeBytes: Int64
    let format: VThumbnailFormat
    let timeMs: Int
    
    var fileSizeFormatted: String {
        return formatFileSize(fileSizeBytes)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.1f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    func toMap() -> [String: Any] {
        return [
            "thumbnailPath": thumbnailPath,
            "width": width,
            "height": height,
            "fileSizeBytes": fileSizeBytes,
            "format": format.rawValue,
            "timeMs": timeMs
        ]
    }
} 