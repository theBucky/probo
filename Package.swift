// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "probo",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "Probo", targets: ["Probo"]),
    .executable(name: "HotPathProfile", targets: ["HotPathProfile"]),
  ],
  targets: [
    .target(name: "ProboCore"),
    .executableTarget(
      name: "Probo",
      dependencies: ["ProboCore"],
      resources: [.copy("Resources")]
    ),
    .executableTarget(
      name: "HotPathProfile",
      dependencies: ["ProboCore"],
      exclude: ["profile.entitlements"]
    ),
    .testTarget(
      name: "ProboTests",
      dependencies: ["ProboCore"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
