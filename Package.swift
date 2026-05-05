// swift-tools-version: 6.2
import PackageDescription

let environment = Context.environment
let kernelPath = environment["COLOR_ANIMA_KERNEL_PATH"].flatMap { $0.isEmpty ? nil : $0 }
let kernelURL = environment["COLOR_ANIMA_KERNEL_URL"].flatMap { $0.isEmpty ? nil : $0 }
let kernelChecksum = environment["COLOR_ANIMA_KERNEL_CHECKSUM"].flatMap { $0.isEmpty ? nil : $0 }
let kernelTargetIsActive = kernelPath != nil || (kernelURL != nil && kernelChecksum != nil)
let kernelBridgeDependencies: [Target.Dependency] = kernelTargetIsActive ? ["ColorAnimaKernel"] : []

var products: [Product] = [
    .library(name: "ColorAnimaDesignStudioTokenManifest", targets: ["ColorAnimaDesignStudioTokenManifest"]),
    .executable(name: "ColorAnimaDesignStudioTokenManifestExtractor", targets: ["ColorAnimaDesignStudioTokenManifestExtractor"]),
    .library(name: "ColorAnimaDesignStudioWriteBack", targets: ["ColorAnimaDesignStudioWriteBack"]),
    .library(name: "ColorAnimaKernelBridge", targets: ["ColorAnimaKernelBridge"]),
    .library(name: "ColorAnimaAppEngine", targets: ["ColorAnimaAppEngine"]),
    .library(name: "ColorAnimaAppWorkspaceApplication", targets: ["ColorAnimaAppWorkspaceApplication"]),
    .library(name: "ColorAnimaAppWorkspaceDesignSystem", targets: ["ColorAnimaAppWorkspaceDesignSystem"]),
    .library(name: "ColorAnimaAppWorkspaceCutEditor", targets: ["ColorAnimaAppWorkspaceCutEditor"]),
    .library(name: "ColorAnimaAppWorkspacePlatformMacOS", targets: ["ColorAnimaAppWorkspacePlatformMacOS"]),
    .library(name: "ColorAnimaAppWorkspaceProjectTree", targets: ["ColorAnimaAppWorkspaceProjectTree"]),
    .library(name: "ColorAnimaAppWorkspaceShell", targets: ["ColorAnimaAppWorkspaceShell"]),
    .library(name: "ColorAnimaAppWorkspace", targets: ["ColorAnimaAppWorkspace"]),
    .library(name: "ColorAnimaAppShell", targets: ["ColorAnimaAppShell"]),
    .executable(name: "ColorAnima", targets: ["ColorAnima"]),
]

var targets: [Target] = [
    .target(
        name: "ColorAnimaDesignStudioTokenManifest",
        path: "Sources/ColorAnimaDesignStudioTokenManifest",
        resources: [.process("Resources")]
    ),
    .executableTarget(
        name: "ColorAnimaDesignStudioTokenManifestExtractor",
        dependencies: ["ColorAnimaDesignStudioTokenManifest"],
        path: "Sources/ColorAnimaDesignStudioTokenManifestExtractor"
    ),
    .target(
        name: "ColorAnimaDesignStudioWriteBack",
        dependencies: [
            "ColorAnimaDesignStudioTokenManifest",
            "ColorAnimaDesignStudioTokenManifestExtractor",
        ],
        path: "Sources/ColorAnimaDesignStudioWriteBack"
    ),
    .target(
        name: "ColorAnimaKernelBridge",
        dependencies: kernelBridgeDependencies,
        path: "Sources/ColorAnimaKernelBridge"
    ),
    .target(
        name: "ColorAnimaAppEngine",
        dependencies: ["ColorAnimaKernelBridge"],
        path: "Sources/ColorAnimaAppEngine"
    ),
    .target(
        name: "ColorAnimaAppWorkspaceApplication",
        dependencies: ["ColorAnimaAppEngine"],
        path: "Sources/ColorAnimaAppWorkspaceApplication"
    ),
    .target(
        name: "ColorAnimaAppWorkspaceDesignSystem",
        path: "Sources/ColorAnimaAppWorkspaceDesignSystem"
    ),
    .target(
        name: "ColorAnimaAppWorkspaceCutEditor",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceDesignSystem",
        ],
        path: "Sources/ColorAnimaAppWorkspaceCutEditor"
    ),
    .target(
        name: "ColorAnimaAppWorkspacePlatformMacOS",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceCutEditor",
        ],
        path: "Sources/ColorAnimaAppWorkspacePlatformMacOS"
    ),
    .target(
        name: "ColorAnimaAppWorkspaceProjectTree",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceDesignSystem",
        ],
        path: "Sources/ColorAnimaAppWorkspaceProjectTree"
    ),
    .target(
        name: "ColorAnimaAppWorkspaceShell",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceDesignSystem",
        ],
        path: "Sources/ColorAnimaAppWorkspaceShell"
    ),
    .target(
        name: "ColorAnimaAppWorkspace",
        dependencies: [
            "ColorAnimaAppEngine",
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceCutEditor",
            "ColorAnimaAppWorkspaceDesignSystem",
            "ColorAnimaAppWorkspacePlatformMacOS",
            "ColorAnimaAppWorkspaceProjectTree",
            "ColorAnimaAppWorkspaceShell",
            "ColorAnimaAppShell",
        ],
        path: "Sources/ColorAnimaAppWorkspace"
    ),
    .target(
        name: "ColorAnimaAppShell",
        path: "Sources/ColorAnimaAppShell"
    ),
    .executableTarget(
        name: "ColorAnima",
        dependencies: [
            "ColorAnimaAppWorkspace",
            "ColorAnimaAppShell",
        ],
        path: "Sources/ColorAnima"
    ),
    .testTarget(
        name: "ColorAnimaKernelBridgeTests",
        dependencies: ["ColorAnimaKernelBridge"],
        path: "Tests/ColorAnimaKernelBridgeTests"
    ),
    .testTarget(
        name: "ColorAnimaAppEngineTests",
        dependencies: ["ColorAnimaAppEngine"],
        path: "Tests/ColorAnimaAppEngineTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspaceTests",
        dependencies: [
            "ColorAnimaAppWorkspace",
            "ColorAnimaAppWorkspaceApplication",
        ],
        path: "Tests/ColorAnimaAppWorkspaceTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspaceApplicationTests",
        dependencies: ["ColorAnimaAppWorkspaceApplication", "ColorAnimaAppEngine"],
        path: "Tests/ColorAnimaAppWorkspaceApplicationTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspaceCutEditorTests",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceCutEditor",
        ],
        path: "Tests/ColorAnimaAppWorkspaceCutEditorTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspaceProjectTreeTests",
        dependencies: [
            "ColorAnimaAppWorkspaceApplication",
            "ColorAnimaAppWorkspaceProjectTree",
        ],
        path: "Tests/ColorAnimaAppWorkspaceProjectTreeTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspacePlatformMacOSTests",
        dependencies: [
            "ColorAnimaAppWorkspaceCutEditor",
            "ColorAnimaAppWorkspacePlatformMacOS",
        ],
        path: "Tests/ColorAnimaAppWorkspacePlatformMacOSTests"
    ),
    .testTarget(
        name: "ColorAnimaAppWorkspaceShellTests",
        dependencies: ["ColorAnimaAppWorkspaceShell"],
        path: "Tests/ColorAnimaAppWorkspaceShellTests"
    ),
    .testTarget(
        name: "ColorAnimaAppShellTests",
        dependencies: ["ColorAnimaAppShell"],
        path: "Tests/ColorAnimaAppShellTests"
    ),
    .testTarget(
        name: "ColorAnimaPublicSurfaceTests",
        path: "Tests/ColorAnimaPublicSurfaceTests"
    ),
    .testTarget(
        name: "ColorAnimaDesignStudioTokenManifestTests",
        dependencies: [
            "ColorAnimaDesignStudioTokenManifest",
            "ColorAnimaDesignStudioTokenManifestExtractor",
        ],
        path: "Tests/ColorAnimaDesignStudioTokenManifestTests"
    ),
    .testTarget(
        name: "ColorAnimaDesignStudioWriteBackTests",
        dependencies: [
            "ColorAnimaDesignStudioWriteBack",
            "ColorAnimaDesignStudioTokenManifest",
            "ColorAnimaDesignStudioTokenManifestExtractor",
        ],
        path: "Tests/ColorAnimaDesignStudioWriteBackTests"
    ),
]

if let kernelPath {
    products.append(.library(name: "ColorAnimaKernel", targets: ["ColorAnimaKernel"]))
    targets.append(.binaryTarget(name: "ColorAnimaKernel", path: kernelPath))
} else if let kernelURL, let kernelChecksum {
    products.append(.library(name: "ColorAnimaKernel", targets: ["ColorAnimaKernel"]))
    targets.append(.binaryTarget(name: "ColorAnimaKernel", url: kernelURL, checksum: kernelChecksum))
}

let package = Package(
    name: "ColorAnima",
    platforms: [
        .macOS(.v14),
    ],
    products: products,
    targets: targets
)
