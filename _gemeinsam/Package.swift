// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EVAGemeinsam",
    // macOS nur, damit der Bau-Läufer die Tests mit `swift test` fährt; die Apps selbst sind iOS.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EVAGemeinsam", targets: ["EVAGemeinsam"])],
    targets: [
        .target(name: "EVAGemeinsam"),
        .testTarget(name: "EVAGemeinsamTests", dependencies: ["EVAGemeinsam"]),
    ]
)
