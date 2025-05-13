// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YTHaishinKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "YTHaishinKit",
            targets: ["YTHaishinKit"]
        ),
    ],
    targets: [
        .target(
            name: "YTHaishinKit",
            dependencies: []
        ),
    ]
)
