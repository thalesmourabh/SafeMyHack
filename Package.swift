// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SafeMyHack",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SafeMyHack", targets: ["SafeMyHack"])
    ],
    targets: [
        .executableTarget(
            name: "SafeMyHack",
            dependencies: [],
            path: ".",
            exclude: [
                "README.md", "LICENSE", "RELEASE_NOTES.md",
                ".gitignore", ".github", "dist", ".build",
                "build.sh", "Resources"
            ],
            sources: [
                "SafeMyHackApp.swift",
                "Frontend/ContentView.swift",
                "Frontend/EFIAnalyzer.swift",
                "Helper/BCMDetector.swift",
                "Helper/ConfigAnalyzer.swift",
                "Helper/KDKDetector.swift",
                "Helper/PayloadManager.swift",
                "Helper/RootPatcher.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
