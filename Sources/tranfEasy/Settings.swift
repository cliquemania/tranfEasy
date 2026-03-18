import Foundation

@MainActor
struct Settings {
    private static let defaults = UserDefaults.standard

    private enum Key: String {
        case lastDestinationPath = "last_destination_path"
        case width = "popup_width"
        case height = "popup_height"
    }

    static var width: Double {
        let value = defaults.double(forKey: Key.width.rawValue)
        return value > 0 ? value : 420
    }

    static var height: Double {
        let value = defaults.double(forKey: Key.height.rawValue)
        return value > 0 ? value : 520
    }

    static var lastDestinationPath: String? {
        get { defaults.string(forKey: Key.lastDestinationPath.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastDestinationPath.rawValue) }
    }
}
