import Flutter
import UIKit
import AVFoundation

public class VVideoCompressorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  
  // MARK: - Properties
  
  private var compressionEngine: VVideoCompressionEngine!
  private var eventSink: FlutterEventSink?
  
  // MARK: - Plugin Registration
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "v_video_compressor", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "v_video_compressor/progress", binaryMessenger: registrar.messenger())
    let instance = VVideoCompressorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }
  
  // MARK: - Initialization
  
  override init() {
    super.init()
    compressionEngine = VVideoCompressionEngine()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
    case "getVideoInfo":
      handleGetVideoInfo(call, result: result)
      
    case "getCompressionEstimate":
      handleGetCompressionEstimate(call, result: result)
      
    case "compressVideo":
      handleCompressVideo(call, result: result)
      
    case "compressVideos":
      handleCompressVideos(call, result: result)
      
    case "cancelCompression":
      handleCancelCompression(result: result)
      
    case "isCompressing":
      result(compressionEngine.isCompressing())
      
    case "getVideoThumbnail":
      handleGetVideoThumbnail(call, result: result)
      
    case "getVideoThumbnails":
      handleGetVideoThumbnails(call, result: result)
      
    case "cleanup":
      handleCleanup(result: result)
      
    case "cleanupFiles":
      handleCleanupFiles(call, result: result)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - Video Compression Methods
  
  private func handleGetVideoInfo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPath = args["videoPath"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video path is required", details: nil))
      return
    }
    
    compressionEngine.getVideoInfo(videoPath) { videoInfo in
      if let info = videoInfo {
        result(info.toMap())
      } else {
        result(nil)
      }
    }
  }
  
  private func handleGetCompressionEstimate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPath = args["videoPath"] as? String,
          let qualityStr = args["quality"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video path and quality are required", details: nil))
      return
    }
    
    let advancedMap = args["advanced"] as? [String: Any]
    
    compressionEngine.getVideoInfo(videoPath) { videoInfo in
      guard let info = videoInfo else {
        result(FlutterError(code: "ERROR", message: "Could not get video info", details: nil))
        return
      }
      
      let quality = VVideoCompressQuality.fromString(qualityStr)
      let advanced = VVideoAdvancedConfig.fromMap(advancedMap)
      let estimate = self.compressionEngine.estimateCompressionSize(info, quality: quality, advanced: advanced)
      
      result(estimate.toMap())
    }
  }
  
  private func handleCompressVideo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPath = args["videoPath"] as? String,
          let configMap = args["config"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video path and config are required", details: nil))
      return
    }
    
    compressionEngine.getVideoInfo(videoPath) { videoInfo in
      guard let info = videoInfo else {
        result(FlutterError(code: "ERROR", message: "Could not get video info", details: nil))
        return
      }
      
      let config = VVideoCompressionConfig.fromMap(configMap)
      
      self.compressionEngine.compressVideo(info, config: config, callback: CompressionCallbackImpl(
        onProgress: { progress in
          self.eventSink?(["progress": progress])
        },
        onComplete: { compressionResult in
          result(compressionResult.toMap())
        },
        onError: { error in
          result(FlutterError(code: "COMPRESSION_ERROR", message: error, details: nil))
        }
      ))
    }
  }
  
  private func handleCompressVideos(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPaths = args["videoPaths"] as? [String],
          let configMap = args["config"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video paths and config are required", details: nil))
      return
    }
    
    let config = VVideoCompressionConfig.fromMap(configMap)
    var results: [VVideoCompressionResult] = []
    let totalVideos = videoPaths.count
    
    func processVideo(at index: Int) {
      guard index < videoPaths.count else {
        // All videos processed
        result(results.map { $0.toMap() })
        return
      }
      
      let videoPath = videoPaths[index]
      
      compressionEngine.getVideoInfo(videoPath) { videoInfo in
        guard let info = videoInfo else {
          // Skip invalid videos but continue with others
          processVideo(at: index + 1)
          return
        }
        
        self.compressionEngine.compressVideo(info, config: config, callback: CompressionCallbackImpl(
          onProgress: { progress in
            // Calculate overall progress
            let overallProgress = (Float(index) + progress) / Float(totalVideos)
            
            // Send batch progress update through event channel
            self.eventSink?([
              "progress": overallProgress,
              "currentIndex": index,
              "total": totalVideos
            ])
          },
          onComplete: { compressionResult in
            results.append(compressionResult)
            processVideo(at: index + 1)
          },
          onError: { error in
            result(FlutterError(code: "COMPRESSION_ERROR", message: "Failed to compress \(info.name): \(error)", details: nil))
          }
        ))
      }
    }
    
    // Start processing from the first video
    processVideo(at: 0)
  }
  
  private func handleCancelCompression(result: @escaping FlutterResult) {
    compressionEngine.cancelCompression()
    result(nil)
  }
  
  private func handleGetVideoThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPath = args["videoPath"] as? String,
          let configMap = args["config"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video path and config are required", details: nil))
      return
    }
    
    compressionEngine.getVideoInfo(videoPath) { videoInfo in
      guard let info = videoInfo else {
        result(FlutterError(code: "ERROR", message: "Could not get video info", details: nil))
        return
      }
      
      let config = VVideoThumbnailConfig.fromMap(configMap)
      
      DispatchQueue.global(qos: .background).async {
        let thumbnail = self.compressionEngine.getVideoThumbnail(info, config: config)
        DispatchQueue.main.async {
          if let thumbnailResult = thumbnail {
            result(thumbnailResult.toMap())
          } else {
            result(FlutterError(code: "ERROR", message: "Failed to generate thumbnail", details: nil))
          }
        }
      }
    }
  }
  
  private func handleGetVideoThumbnails(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let videoPath = args["videoPath"] as? String,
          let configMaps = args["configs"] as? [[String: Any]] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Video path and configs are required", details: nil))
      return
    }
    
    compressionEngine.getVideoInfo(videoPath) { videoInfo in
      guard let info = videoInfo else {
        result(FlutterError(code: "ERROR", message: "Could not get video info", details: nil))
        return
      }
      
      DispatchQueue.global(qos: .background).async {
        var thumbnails: [[String: Any]] = []
        
        for configMap in configMaps {
          let config = VVideoThumbnailConfig.fromMap(configMap)
          if let thumbnail = self.compressionEngine.getVideoThumbnail(info, config: config) {
            thumbnails.append(thumbnail.toMap())
          }
        }
        
        DispatchQueue.main.async {
          result(thumbnails)
        }
      }
    }
  }
  
  // MARK: - FlutterStreamHandler Implementation
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

// MARK: - Compression Callback Implementation

private class CompressionCallbackImpl: VVideoCompressionEngine.CompressionCallback {
  private let onProgressCallback: (Float) -> Void
  private let onCompleteCallback: (VVideoCompressionResult) -> Void
  private let onErrorCallback: (String) -> Void
  
  init(onProgress: @escaping (Float) -> Void, 
       onComplete: @escaping (VVideoCompressionResult) -> Void, 
       onError: @escaping (String) -> Void) {
    self.onProgressCallback = onProgress
    self.onCompleteCallback = onComplete
    self.onErrorCallback = onError
  }
  
  func onProgress(_ progress: Float) {
    onProgressCallback(progress)
  }
  
  func onComplete(_ result: VVideoCompressionResult) {
    onCompleteCallback(result)
  }
  
  func onError(_ error: String) {
    onErrorCallback(error)
  }
}

// MARK: - Legacy Thumbnail Generation (Fallback)

extension VVideoCompressorPlugin {
  
  private func generateVideoThumbnail(videoPath: String, config: [String: Any]) -> [String: Any]? {
    guard let url = createURLFromPath(videoPath) else { 
      print("VVideoCompressorPlugin: Failed to create URL from path: \(videoPath)")
      return nil 
    }
    
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    let timeMs = config["timeMs"] as? Int ?? 0
    let maxWidth = config["maxWidth"] as? Int
    let maxHeight = config["maxHeight"] as? Int
    let format = config["format"] as? String ?? "JPEG"
    let quality = config["quality"] as? Int ?? 80
    let outputPath = config["outputPath"] as? String
    
    let time = CMTime(seconds: Double(timeMs) / 1000.0, preferredTimescale: 600)
    
    do {
      let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
      var image = UIImage(cgImage: cgImage)
      
      // Scale image if dimensions are specified
      if let maxW = maxWidth, let maxH = maxHeight {
        image = scaleImageWithAspectRatio(image: image, maxWidth: maxW, maxHeight: maxH)
      } else if let maxW = maxWidth {
        let aspectRatio = image.size.height / image.size.width
        let newHeight = CGFloat(maxW) * aspectRatio
        image = scaleImageWithAspectRatio(image: image, maxWidth: maxW, maxHeight: Int(newHeight))
      } else if let maxH = maxHeight {
        let aspectRatio = image.size.width / image.size.height
        let newWidth = CGFloat(maxH) * aspectRatio
        image = scaleImageWithAspectRatio(image: image, maxWidth: Int(newWidth), maxHeight: maxH)
      }
      
      // Create output file
      let outputFile = createThumbnailOutputFile(
        outputPath: outputPath,
        videoName: URL(fileURLWithPath: videoPath).lastPathComponent,
        format: format,
        timeMs: timeMs
      )
      
      // Save image to file
      let imageData: Data?
      if format == "PNG" {
        imageData = image.pngData()
      } else {
        imageData = image.jpegData(compressionQuality: CGFloat(quality) / 100.0)
      }
      
      guard let data = imageData else { return nil }
      
      do {
        try data.write(to: outputFile)
        
        return [
          "thumbnailPath": outputFile.path,
          "width": Int(image.size.width),
          "height": Int(image.size.height),
          "fileSizeBytes": data.count,
          "format": format,
          "timeMs": timeMs
        ]
      } catch {
        return nil
      }
      
    } catch {
      return nil
    }
  }
  
  private func createThumbnailOutputFile(outputPath: String?, videoName: String, format: String, timeMs: Int) -> URL {
    let outputDirectory: URL
    
    if let path = outputPath {
      outputDirectory = URL(fileURLWithPath: path)
    } else {
      outputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VideoThumbnails")
    }
    
    // Create directory if it doesn't exist
    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    let timestamp = Int(Date().timeIntervalSince1970)
    let videoBaseName = URL(fileURLWithPath: videoName).deletingPathExtension().lastPathComponent
    let fileExtension = format == "PNG" ? ".png" : ".jpg"
          let filename = "thumb_\(videoBaseName)_\(timeMs)ms_\(timestamp)\(fileExtension)"
    
    return outputDirectory.appendingPathComponent(filename)
  }
  
  private func createURLFromPath(_ path: String) -> URL? {
    // First, try to create URL from string (for proper URLs)
    if let url = URL(string: path), url.scheme != nil {
      return url
    }
    
    // If that fails, treat it as a file path
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path)
    }
    
    // Try to handle file:// URLs that might be passed as strings
    if path.hasPrefix("file://") {
      return URL(string: path)
    }
    
    // Last resort: try as relative path from documents directory
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsPath.appendingPathComponent(path)
  }

  private func scaleImageWithAspectRatio(image: UIImage, maxWidth: Int, maxHeight: Int) -> UIImage {
    let originalSize = image.size
    let aspectRatio = originalSize.width / originalSize.height
    
    let targetSize: CGSize
    if originalSize.width / CGFloat(maxWidth) > originalSize.height / CGFloat(maxHeight) {
      // Width is limiting factor
      targetSize = CGSize(width: maxWidth, height: Int(CGFloat(maxWidth) / aspectRatio))
    } else {
      // Height is limiting factor
      targetSize = CGSize(width: Int(CGFloat(maxHeight) * aspectRatio), height: maxHeight)
    }
    
    UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
    image.draw(in: CGRect(origin: .zero, size: targetSize))
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return scaledImage ?? image
  }
  
  private func handleCleanup(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .background).async {
      let cleanupResult = self.compressionEngine.cleanup()
      DispatchQueue.main.async {
        result(cleanupResult)
      }
    }
  }
  
  private func handleCleanupFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments are required", details: nil))
      return
    }
    
    let deleteThumbnails = args["deleteThumbnails"] as? Bool ?? true
    let deleteCompressedVideos = args["deleteCompressedVideos"] as? Bool ?? false
    let clearCache = args["clearCache"] as? Bool ?? true
    
    DispatchQueue.global(qos: .background).async {
      let cleanupResult = self.compressionEngine.cleanupFiles(
        deleteThumbnails: deleteThumbnails,
        deleteCompressedVideos: deleteCompressedVideos,
        clearCache: clearCache
      )
      DispatchQueue.main.async {
        result(cleanupResult)
      }
    }
  }
}
