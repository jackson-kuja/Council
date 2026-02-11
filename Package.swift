// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Council",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Council", targets: ["Council"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elevenlabs/elevenlabs-swift-sdk.git", from: "3.0.0"),
        .package(url: "https://github.com/elevenlabs/components-swift.git", branch: "main"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "Council",
            dependencies: [
                .product(name: "ElevenLabs", package: "elevenlabs-swift-sdk"),
                .product(name: "ElevenLabsComponents", package: "components-swift"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
            ],
            path: "Council"
        ),
    ]
)
