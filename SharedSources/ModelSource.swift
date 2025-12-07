import Foundation

public enum ModelSource: String, Codable {
    case app = "app"
    case macWhisper = "macWhisper"

    public var displayName: String {
        switch self {
        case .app:
            return "App"
        case .macWhisper:
            return "MacWhisper"
        }
    }

    public var isReadOnly: Bool {
        switch self {
        case .app:
            return false
        case .macWhisper:
            return true
        }
    }
}
