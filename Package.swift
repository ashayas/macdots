// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDots",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacDots", targets: ["MacDots"])
    ],
    targets: [
        .executableTarget(
            name: "MacDots",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
