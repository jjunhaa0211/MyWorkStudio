import ProjectDescription

let project = Project(
    name: "DofficeKit",
    packages: [
        .remote(url: "https://github.com/migueldeicaza/SwiftTerm.git", requirement: .exact("1.12.0")),
        .remote(url: "https://github.com/apple/swift-collections.git", requirement: .upToNextMajor(from: "1.1.0")),
    ],
    settings: .settings(
        base: [
            "DEAD_CODE_STRIPPING": "YES",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule",
                "SWIFT_COMPILATION_MODE": "wholemodule",
                "GCC_OPTIMIZATION_LEVEL": "s",
            ]),
        ]
    ),
    targets: [
        Target(
            name: "DofficeKit",
            platform: .macOS,
            product: .staticFramework,
            bundleId: "com.junha.doffice.kit",
            deploymentTarget: .macOS(targetVersion: "14.0"),
            sources: ["Sources/**"],
            dependencies: [
                .project(target: "DesignSystem", path: .relativeToRoot("Projects/DesignSystem")),
                .package(product: "SwiftTerm"),
                .package(product: "OrderedCollections"),
            ]
        ),
        Target(
            name: "DofficeKitTests",
            platform: .macOS,
            product: .unitTests,
            bundleId: "com.junha.doffice.kit.tests",
            deploymentTarget: .macOS(targetVersion: "14.0"),
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "DofficeKit"),
            ]
        ),
    ]
)
