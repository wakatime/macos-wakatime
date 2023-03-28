// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WakaTime",
    dependencies: [
        .package(url: "https://github.com/Realm/SwiftLint", from: "0.51.0"),
    ]
)
