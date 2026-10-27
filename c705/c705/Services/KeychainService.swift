//
//  KeychainService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: A safe place to store secrets such as the login token. The Keychain
//  is iOS's encrypted vault, so these values are not kept in ordinary
//  files where they could be read.
//

import Foundation
import Security

// Use KeychainService.shared everywhere. It saves, reads and deletes small pieces of text, or
// any Codable object, under a name (key).
class KeychainService {
    static let shared = KeychainService()
    
    // Labels everything this app stores, so it never mixes up with other apps' items.
    private let service = "com.c705.app"
    
    private init() {}
    
    // MARK: - Save
    
    // Saves a piece of text. It deletes any older value with the same key first, because the
    // Keychain refuses to overwrite. Returns true if it worked.
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Delete existing item first
        _ = delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // The value can only be read while the phone is unlocked, and it is never copied to
            // other devices or backups.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve
    
    // Reads the saved text back. The ? means it returns nothing if the key was never saved.
    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    // MARK: - Delete
    
    // Removes one saved value. Deleting something that is already gone counts as success.
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Save Codable Objects
    
    // The same as saving text, but for a whole object (such as the signed-in user). It turns
    // the object into JSON first.
    func save<T: Codable>(_ object: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(object) else {
            return false
        }
        
        // Delete existing item first
        _ = delete(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve Codable Objects
    
    // Reads a saved object back and turns the JSON into the type you ask for.
    func get<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Clear All
    
    // Wipes everything this app stored. Used when signing out.
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

