import Foundation

/// Calculates the total-byte budget used to approximate an explicit video
/// bitrate with `AVAssetExportSession.fileLengthLimit`.
enum VVideoFileLengthBudget {
    static let fallbackAudioBitrate = 128_000
    static let maximumBitrate = Int(Int32.max)

    static func audioBitrate(
        removesAudio: Bool,
        hasAudioTrack: Bool,
        estimatedAudioBitrate: Double?
    ) -> Int {
        guard !removesAudio, hasAudioTrack else { return 0 }
        guard let estimatedAudioBitrate = estimatedAudioBitrate,
              estimatedAudioBitrate.isFinite,
              estimatedAudioBitrate >= 1,
              estimatedAudioBitrate <= Double(maximumBitrate) else {
            return fallbackAudioBitrate
        }
        return Int(estimatedAudioBitrate.rounded(.down))
    }

    static func fileLengthLimit(
        explicitVideoBitrate: Int?,
        audioBitrate: Int,
        durationSeconds: Double
    ) -> Int64? {
        guard let videoBitrate = explicitVideoBitrate,
              videoBitrate > 0,
              videoBitrate <= maximumBitrate,
              audioBitrate >= 0,
              audioBitrate <= maximumBitrate,
              durationSeconds.isFinite,
              durationSeconds > 0 else {
            return nil
        }

        // Convert each operand before adding so an extreme pair of Int values
        // cannot overflow before the range check below.
        let totalBitrate = Double(videoBitrate) + Double(audioBitrate)
        let bytes = totalBitrate * durationSeconds / 8.0
        guard bytes.isFinite,
              bytes >= 1,
              bytes < Double(Int64.max) else {
            return nil
        }
        return Int64(bytes.rounded(.down))
    }
}
