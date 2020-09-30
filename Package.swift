// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "swift-context",
    products: [
        .library(
            name: "Baggage",
            targets: [
                "Baggage",
            ]
        ),
        .library(
            name: "BaggageContext",
            targets: [
                "BaggageContext",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Baggage",
            dependencies: []
        ),

        .target(
            name: "BaggageContext",
            dependencies: [
                "Baggage",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Tests

        .testTarget(
            name: "BaggageTests",
            dependencies: [
                "Baggage",
            ]
        ),

        .testTarget(
            name: "BaggageContextTests",
            dependencies: [
                "Baggage",
                "BaggageContext",
            ]
        ),

        // ==== --------------------------------------------------------------------------------------------------------
        // MARK: Performance / Benchmarks

        .target(
            name: "BaggageContextBenchmarks",
            dependencies: [
                "BaggageContext",
                "BaggageContextBenchmarkTools",
            ]
        ),
        .target(
            name: "BaggageContextBenchmarkTools",
            dependencies: []
        ),
    ]
)
