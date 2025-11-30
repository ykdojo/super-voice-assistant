import Foundation

struct ReplacementsConfig: Codable {
    var textReplacements: [String: String]

    static let empty = ReplacementsConfig(textReplacements: [:])
}

class TextReplacements {
    static let shared = TextReplacements()

    private var config: ReplacementsConfig = .empty

    private var configFileURL: URL {
        let currentDirectory = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent("config.json")
    }

    private init() {
        loadConfig()
    }

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            print("No config file found at \(configFileURL.path)")
            return
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            config = try JSONDecoder().decode(ReplacementsConfig.self, from: data)
            print("Loaded \(config.textReplacements.count) text replacements")
        } catch {
            print("Failed to load config: \(error)")
        }
    }

    /// Reloads config from disk (call this if you want hot-reload)
    func reloadConfig() {
        loadConfig()
    }

    /// Apply all text replacements to the input string (case-sensitive)
    func applyReplacements(_ text: String) -> String {
        var result = text
        for (find, replace) in config.textReplacements {
            result = result.replacingOccurrences(of: find, with: replace)
        }
        return result
    }
}
