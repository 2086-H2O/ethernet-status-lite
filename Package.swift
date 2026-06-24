// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EthernetStatusLite",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EthernetStatusLite",
            path: "Sources/EthernetStatus",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
            ]
        ),
    ]
)
