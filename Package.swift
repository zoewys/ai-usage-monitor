// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AIUsageMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AIUsageMonitor", targets: ["AIUsageMonitor"])
    ],
    targets: [
        .target(
            name: "AIUsageMonitorCore"
        ),
        .executableTarget(
            name: "AIUsageMonitor",
            dependencies: ["AIUsageMonitorCore"]
        ),
        .testTarget(
            name: "AIUsageMonitorCoreTests",
            dependencies: ["AIUsageMonitorCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
