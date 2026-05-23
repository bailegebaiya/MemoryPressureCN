// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MemoryPressureCN",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MemoryPressureCN", targets: ["MemoryPressureCN"])
    ],
    targets: [
        .executableTarget(name: "MemoryPressureCN")
    ]
)
