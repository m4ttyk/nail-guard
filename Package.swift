// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NailGuard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NailGuard"),
        .testTarget(name: "NailGuardTests", dependencies: ["NailGuard"]),
    ]
)
