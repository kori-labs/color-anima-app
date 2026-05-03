public enum AppShellMetadata {
    public static let displayName = "Color Anima"
    public static let repositoryRole = "Public app and release intake surface"
    public static let statusLine = "Private compute source is kept outside this repository."

    public static let operationalSurfaces = [
        OperationalSurface(name: "App engine", state: "public Swift client"),
        OperationalSurface(name: "Kernel bridge", state: "binary target boundary"),
        OperationalSurface(name: "Core intake", state: "encrypted release asset"),
    ]
}

public struct OperationalSurface: Equatable, Sendable {
    public let name: String
    public let state: String

    public init(name: String, state: String) {
        self.name = name
        self.state = state
    }
}
