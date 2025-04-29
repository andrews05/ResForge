// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Plugins",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "RFSupport",
            targets: ["RFSupport"]),
        .library(
            name: "HexEditor",
            targets: ["HexEditor"]),
        .library(
            name: "TemplateEditor",
            targets: ["TemplateEditor"]),
        .library(
            name: "DialogEditor",
            targets: ["DialogEditor"]),
        .library(
            name: "ImageEditor",
            targets: ["ImageEditor"]),
        .library(
            name: "MenuEditor",
            targets: ["MenuEditor"]),
        .library(
            name: "NovaTools",
            targets: ["NovaTools"]),
        .library(
            name: "SoundEditor",
            targets: ["SoundEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", "1.0.0"..<"2.0.0"),
        .package(url: "https://github.com/HexFiend/HexFiend.git", branch: "package")
    ],
    targets: [
        .target(
            name: "RFSupport"),
        .target(
            name: "HexEditor",
            dependencies: [.target(name: "RFSupport"),
                           .product(name: "HexFiend", package: "HexFiend")]),
        .target(
            name: "TemplateEditor",
            dependencies: [.target(name: "RFSupport"),
                           .product(name: "OrderedCollections", package: "swift-collections")],
            resources: [.process("Templates.rsrc")]),
        .target(
            name: "DialogEditor",
            dependencies: [.target(name: "RFSupport")],
            resources: [.process("StdSystemIcons.rsrc")]),
        .target(
            name: "ImageEditor",
            dependencies: [.target(name: "RFSupport"),
                           .product(name: "OrderedCollections", package: "swift-collections")]),
        .target(
            name: "MenuEditor",
            dependencies: [.target(name: "RFSupport")]),
        .target(
            name: "NovaTools",
            dependencies: [.target(name: "RFSupport"),
                           .product(name: "OrderedCollections", package: "swift-collections")],
            resources: [.process("Templates.rsrc")]),
        .target(
            name: "SoundEditor",
            dependencies: [.target(name: "RFSupport")]),
    ]
)
