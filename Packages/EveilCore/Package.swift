// swift-tools-version: 6.0
import PackageDescription

// Noyau sans interface ni dependance (Foundation seule) : sessions, fin, evaluation, textes.
let package = Package(
    name: "EveilCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "EveilCore", targets: ["EveilCore"]),
    ],
    targets: [
        .target(name: "EveilCore"),
        // Harnais de tests : XCTest et Swift Testing ne sont pas livres avec
        // les Command Line Tools (voir docs/tests.md).
        .executableTarget(
            name: "eveilcore-check",
            dependencies: ["EveilCore"]
        ),
    ]
)
