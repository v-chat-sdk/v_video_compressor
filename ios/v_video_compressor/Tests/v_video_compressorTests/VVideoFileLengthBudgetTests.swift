import XCTest
@testable import v_video_compressor

final class VVideoFileLengthBudgetTests: XCTestCase {
    func testNoExplicitVideoBitratePreservesPresetBehavior() {
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: nil,
                audioBitrate: 128_000,
                durationSeconds: 10
            )
        )
    }

    func testVideoOnlyBudgetDoesNotReserveAudioBytes() {
        let audioBitrate = VVideoFileLengthBudget.audioBitrate(
            removesAudio: false,
            hasAudioTrack: false,
            estimatedAudioBitrate: nil
        )

        XCTAssertEqual(audioBitrate, 0)
        XCTAssertEqual(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: audioBitrate,
                durationSeconds: 10
            ),
            312_500
        )
    }

    func testPreservedAudioUsesTheSourceTrackEstimate() {
        let audioBitrate = VVideoFileLengthBudget.audioBitrate(
            removesAudio: false,
            hasAudioTrack: true,
            estimatedAudioBitrate: 96_000
        )

        XCTAssertEqual(audioBitrate, 96_000)
        XCTAssertEqual(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: audioBitrate,
                durationSeconds: 10
            ),
            432_500
        )
    }

    func testRemovedAudioOverridesTheSourceTrackEstimate() {
        XCTAssertEqual(
            VVideoFileLengthBudget.audioBitrate(
                removesAudio: true,
                hasAudioTrack: true,
                estimatedAudioBitrate: 256_000
            ),
            0
        )
    }

    func testUnknownSourceAudioRateUsesConservativeFallback() {
        XCTAssertEqual(
            VVideoFileLengthBudget.audioBitrate(
                removesAudio: false,
                hasAudioTrack: true,
                estimatedAudioBitrate: nil
            ),
            128_000
        )
        XCTAssertEqual(
            VVideoFileLengthBudget.audioBitrate(
                removesAudio: false,
                hasAudioTrack: true,
                estimatedAudioBitrate: .nan
            ),
            128_000
        )
        XCTAssertEqual(
            VVideoFileLengthBudget.audioBitrate(
                removesAudio: false,
                hasAudioTrack: true,
                estimatedAudioBitrate: 0.5
            ),
            128_000
        )
    }

    func testTrimmedDurationControlsTheBudget() {
        XCTAssertEqual(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: 128_000,
                durationSeconds: 2.5
            ),
            118_125
        )
    }

    func testInvalidAndOverflowingInputsAreRejected() {
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 0,
                audioBitrate: 0,
                durationSeconds: 1
            )
        )
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: -1,
                durationSeconds: 1
            )
        )
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: 0,
                durationSeconds: .infinity
            )
        )
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: Int.max,
                audioBitrate: Int.max,
                durationSeconds: 10
            )
        )
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: VVideoFileLengthBudget.maximumBitrate + 1,
                audioBitrate: 0,
                durationSeconds: 1
            )
        )
        XCTAssertNil(
            VVideoFileLengthBudget.fileLengthLimit(
                explicitVideoBitrate: 250_000,
                audioBitrate: VVideoFileLengthBudget.maximumBitrate + 1,
                durationSeconds: 1
            )
        )
    }
}
