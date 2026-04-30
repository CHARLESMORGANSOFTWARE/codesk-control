// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeskControl",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "codesk", targets: ["CodeskControl"])
    ],
    targets: [
        .executableTarget(
            name: "CodeskControl"
        ),
        .testTarget(
            name: "CodeskControlTests",
            dependencies: ["CodeskControl"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
