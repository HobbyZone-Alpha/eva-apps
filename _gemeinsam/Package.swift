// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EVAGemeinsam",
    platforms: [.iOS(.v17)],
    products: [.library(name: "EVAGemeinsam", targets: ["EVAGemeinsam"])],
    targets: [.target(name: "EVAGemeinsam")]
)
