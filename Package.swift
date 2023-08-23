// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PythonModuleBuilder",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PythonModuleBuilder",
            targets: ["PythonModuleBuilder"]),
    ],
    dependencies: [
        .package(url: "https://github.com/PythonSwiftLink/PythonLib", branch: "main"),
        .package(url: "https://github.com/PythonSwiftLink/PythonSwiftCore", branch: "testing"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PythonModuleBuilder",
            dependencies: [
                "PythonLib",
                "PythonSwiftCore"
            ],
            swiftSettings: [ .define("BEEWARE", nil)]
        ),
        .testTarget(
            name: "PythonModuleBuilderTests",
            dependencies: ["PythonModuleBuilder"]),
    ]
)
