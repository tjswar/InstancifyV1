// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Instancify",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Instancify",
            targets: ["Instancify"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        .package(url: "https://github.com/aws-amplify/aws-sdk-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "Instancify",
            dependencies: [
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "AWSEC2", package: "aws-sdk-swift"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
                .product(name: "AWSCloudWatch", package: "aws-sdk-swift"),
                .product(name: "AWSDynamoDB", package: "aws-sdk-swift"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]),
        .testTarget(
            name: "InstancifyTests",
            dependencies: ["Instancify"]),
    ]
) 