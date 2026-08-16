// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "v_video_compressor",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
        .library(
            name: "v-video-compressor",
            targets: ["v_video_compressor"]
        ),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "v_video_compressor",
            dependencies: [
                .product(
                    name: "FlutterFramework",
                    package: "FlutterFramework"
                ),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "v_video_compressorTests",
            dependencies: ["v_video_compressor"]
        ),
    ]
)
