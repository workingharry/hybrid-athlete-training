// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZeroTypingExpense",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ZeroTypingExpense",
            targets: ["ZeroTypingExpense"]
        ),
    ],
    targets: [
        .target(
            name: "ZeroTypingExpense",
            dependencies: [],
            exclude: ["App.swift", "Info.plist"]
        ),
        .testTarget(
            name: "ZeroTypingExpenseTests",
            dependencies: ["ZeroTypingExpense"]
        ),
    ]
)
