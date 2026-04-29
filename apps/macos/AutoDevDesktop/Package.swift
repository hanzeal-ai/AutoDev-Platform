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
            exclude: ["Views/Components/Chat/Resources"],
            sources: ["."],
            resources: [
                .copy("Views/Components/Chat/Resources/chat-message.html"),
            ]
        ),
        .testTarget(
            name: "AutoDevDesktopTests",
            dependencies: ["AutoDevDesktop"],
            path: "Tests/AutoDevDesktopTests"
        ),
    ]
)
