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

    /// Process text: apply replacements, strip enclosing quotes, and clean formatting
    func processText(_ text: String) -> String {
        var result = text
        for (find, replace) in config.textReplacements {
            result = result.replacingOccurrences(of: find, with: replace)
        }

        // Remove enclosing quotation marks if the entire string is wrapped in them
        result = stripEnclosingQuotes(result)

        // Clean up bullet point formatting (leading hyphens and continuation spaces)
        result = cleanBulletFormatting(result)

        return result
    }

    /// Removes leading hyphens and continuation line spaces from transcription output
    private func cleanBulletFormatting(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")

        for i in 0..<lines.count {
            var line = lines[i]

            // Remove leading "- " (hyphen followed by space) from lines
            if line.hasPrefix("- ") {
                line = String(line.dropFirst(2))
            }

            // Remove single leading space (continuation line formatting)
            if line.hasPrefix(" ") && !line.hasPrefix("  ") {
                line = String(line.dropFirst(1))
            }

            lines[i] = line
        }

        return lines.joined(separator: "\n")
    }

    /// Removes quotation marks if they enclose the entire string
    private func stripEnclosingQuotes(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Check for various quote pairs
        let quotePairs: [(String, String)] = [
            ("\"", "\""),           // straight double quotes
            ("'", "'"),             // straight single quotes
            ("\u{201C}", "\u{201D}"), // curly double quotes " "
            ("\u{2018}", "\u{2019}"), // curly single quotes ' '
        ]

        for (open, close) in quotePairs {
            if trimmed.hasPrefix(open) && trimmed.hasSuffix(close) && trimmed.count > open.count + close.count {
                let startIndex = trimmed.index(trimmed.startIndex, offsetBy: open.count)
                let endIndex = trimmed.index(trimmed.endIndex, offsetBy: -close.count)
                return String(trimmed[startIndex..<endIndex])
            }
        }

        return text
    }
}
