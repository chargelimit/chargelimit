// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChargeLimit",
    platforms: [.macOS("27.0")],
    targets: [
        .target(name: "ChargeLimitKit"),
        .executableTarget(name: "ChargeLimit", dependencies: ["ChargeLimitKit"]),
        .testTarget(name: "ChargeLimitKitTests", dependencies: ["ChargeLimitKit"]),
    ]
)
