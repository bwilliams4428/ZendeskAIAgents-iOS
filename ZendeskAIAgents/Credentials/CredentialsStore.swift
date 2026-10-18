//
//  CredentialsStore.swift
//  ZendeskAIAgents
//
//  Keychain-backed credential storage. The user-supplied Zendesk configuration
//  is persisted to the iOS Keychain so it survives app restarts but never
//  touches disk in plaintext or ships with the binary.
//

import Foundation
import Security

extension Notification.Name {
    static let zendeskCredentialsChanged = Notification.Name("zendeskCredentialsChanged")
}

final class CredentialsStore {

    private let service = "com.zendeskaiagents.app.credentials"
    private let account = "zendesk-config"

    var hasCredentials: Bool {
        load() != nil
    }

    func load() -> ZendeskCredentials? {
        guard let data = readKeychain() else { return nil }
        return try? JSONDecoder().decode(ZendeskCredentials.self, from: data)
    }

    func save(_ credentials: ZendeskCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try writeKeychain(data: data)
        NotificationCenter.default.post(name: .zendeskCredentialsChanged, object: nil)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        NotificationCenter.default.post(name: .zendeskCredentialsChanged, object: nil)
    }

    // MARK: - Keychain primitives

    private func readKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    private func writeKeychain(data: Data) throws {
        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "CredentialsStore",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Keychain write failed (OSStatus \(status))"]
            )
        }
    }
}
