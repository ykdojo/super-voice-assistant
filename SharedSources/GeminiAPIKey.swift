import Foundation
import Security

/// Resolves the Gemini API key from (in order):
/// 1. GEMINI_API_KEY environment variable
/// 2. macOS keychain generic password with service "gemini-api-key"
///    (store it with: security add-generic-password -U -s gemini-api-key -a "$USER" -w YOUR_KEY)
/// 3. .env file in the current working directory
public enum GeminiAPIKey {
    public static func resolve() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let keychainKey = fromKeychain() {
            return keychainKey
        }
        return fromEnvFile()
    }

    private static func fromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gemini-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    private static func fromEnvFile() -> String? {
        guard let envContent = try? String(contentsOfFile: ".env", encoding: .utf8) else {
            return nil
        }
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("GEMINI_API_KEY=") {
                let key = String(trimmed.dropFirst("GEMINI_API_KEY=".count))
                return key.isEmpty ? nil : key
            }
        }
        return nil
    }
}
