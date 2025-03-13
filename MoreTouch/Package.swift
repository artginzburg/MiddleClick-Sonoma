// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MoreTouch",
  platforms: [.macOS(.v10_13)],
  products: [
    .library(name: "MoreTouchCore", targets: ["MoreTouchCore"])
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages this package depends on.
    .systemLibrary(name: "MultitouchSupport"),
    .target(
      name: "MoreTouchCore",
      dependencies: ["MultitouchSupport"],
      linkerSettings: [
        .linkedFramework("MultitouchSupport"),
        .unsafeFlags(["-F/System/Library/PrivateFrameworks"])
      ]
    ),
  ]
)
