// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Plugins",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "RFSupport",
            targets: ["RFSupport"]),
//        .library(
//            name: "HexEditor",
//            targets: ["HexEditor"]),
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
//        .package(url: "https://github.com/HexFiend/HexFiend.git", branch: "package"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", "0.15.0"..<"0.16.0", traits: [])
    ],
    targets: [
        .target(
            name: "RFSupport"),
//        .target(
//            name: "HexEditor",
//            dependencies: [.target(name: "RFSupport"),
//                           .product(name: "HexFiend", package: "HexFiend")]),
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
                           .target(name: "TemplateEditor"),
                           .target(name: "DialogEditor"),
                           .target(name: "ImageEditor"),
                           .product(name: "OrderedCollections", package: "swift-collections"),
                           .product(name: "Parsing", package: "swift-parsing")],
            resources: [.process("Templates.rsrc")]),
        .target(
            name: "SoundEditor",
            dependencies: [.target(name: "RFSupport")]),
    ],
    swiftLanguageModes: [.v5]
)
