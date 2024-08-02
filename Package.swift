// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-persistable-timer",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PersistableTimerCore",
            targets: ["PersistableTimerCore"]
        ),
        .library(
            name: "PersistableTimer",
            targets: ["PersistableTimer"]
        ),
        .library(
            name: "PersistableTimerText",
            targets: ["PersistableTimerText"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-testing", exact: "0.10.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PersistableTimerCore"
        ),
        .target(
            name: "PersistableTimer",
            dependencies: [
                "PersistableTimerCore",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PersistableTimerText",
            dependencies: ["PersistableTimerCore"]
        ),
        .testTarget(
            name: "PersistableTimerCoreTests",
            dependencies: [
                "PersistableTimerCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ]
)
