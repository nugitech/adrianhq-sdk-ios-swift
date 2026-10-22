// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AdrianChat",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AdrianChat", targets: ["AdrianChat"]),
    ],
    targets: [
        .target(
            name: "AdrianChat",
            path: "Sources/AdrianChat",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ]
)
