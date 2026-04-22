// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AutoDevDesktop",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "AutoDevDesktop", targets: ["AutoDevDesktop"]),
    ],
    targets: [
        .executableTarget(
            name: "AutoDevDesktop",
            path: "Sources/AutoDevDesktop",
            sources: ["."]
        ),
        .testTarget(
            name: "AutoDevDesktopTests",
            dependencies: ["AutoDevDesktop"],
            path: "Tests/AutoDevDesktopTests"
        ),
    ]
)
