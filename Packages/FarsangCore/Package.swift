// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FarsangCore",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "FarsangCore", targets: ["FarsangCore"]),
    ],
    targets: [
        .target(
            name: "FarsangCore",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "FarsangCoreTests",
            dependencies: ["FarsangCore"],
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
    ],
    swiftLanguageModes: [.v6]
)
