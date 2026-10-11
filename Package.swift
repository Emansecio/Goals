// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Goals",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Goals", path: "Sources/Goals")
    ]
)
