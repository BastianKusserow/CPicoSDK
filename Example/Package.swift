// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Example",
    products: [
        .library(name: "Example", type: .static, targets: ["Example"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/gonzalolarralde/CPicoSDK",
            exact: "2.2.7",
            traits: [
                .init(name: "Platform_RP2040"),
                .init(name: "BootStage2_W25Q080"),
                .init(name: "StdIO_Automatic"),

                // - Pico W
                .init(name: "Variant_RP2040"),
                .init(name: "Radio_CYW43439"),
            ]
        ),
    ],
    targets: [
        .target(
            name: "HAL",
            dependencies: ["CPicoSDK"],
            path: "Sources/Example/HAL"
        ),
        .target(
            name: "Example",
            dependencies: ["CPicoSDK", "HAL"],
            path: "Sources/Example",
            exclude: ["HAL"],
            plugins: [.plugin(name: "PIOASM", package: "CPicoSDK")]
        ),
    ]
)
