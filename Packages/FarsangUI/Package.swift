// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FarsangUI",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "FarsangUI", targets: ["FarsangUI"])
    ],
    targets: [
        .target(
            name: "FarsangUI",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "FarsangUITests",
            dependencies: ["FarsangUI"],
            swiftSettings: [.treatAllWarnings(as: .error)]
        )
    ],
    swiftLanguageModes: [.v6]
)
