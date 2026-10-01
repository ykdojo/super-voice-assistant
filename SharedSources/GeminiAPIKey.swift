import Foundation
import Security

/// Resolves the Gemini API key from (in order):
/// 1. GEMINI_API_KEY environment variable
/// 2. macOS keychain generic password with service "gemini-api-key"
///    (store it with: security add-generic-password -U -s gemini-api-key -a "$USER" -w YOUR_KEY)
/// 3. .env file in the current working directory
public enum GeminiAPIKey {
    public static func resolve(environmentVariable: String = "GEMINI_API_KEY", keychainService: String = "gemini-api-key") -> String? {
        if let envKey = ProcessInfo.processInfo.environment[environmentVariable], !envKey.isEmpty {
            return envKey
        }
        if let keychainKey = fromKeychain(service: keychainService) {
            return keychainKey
        }
        return fromEnvFile(variable: environmentVariable)
    }

    private static func fromKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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

    private static func fromEnvFile(variable: String) -> String? {
        guard let envContent = try? String(contentsOfFile: ".env", encoding: .utf8) else {
            return nil
        }
        for line in envContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\(variable)=") {
                let key = String(trimmed.dropFirst(variable.count + 1))
                return key.isEmpty ? nil : key
            }
        }
        return nil
    }
}
