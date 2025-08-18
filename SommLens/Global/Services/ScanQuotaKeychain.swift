//
//  ScanQuotaKeychain.swift
//  SommLens
//
//  Created by Logan Rausch on 5/28/25.
//

import Foundation
import Security
import os

enum ScanQuotaKeychain { }

extension ScanQuotaKeychain {
    private static let rcService = "com.sommlens.rc.userid"
    private static let rcAccount = "appUserID"

    // Used in incrementScanCount - saves count
    static func saveCount(_ count: Int, for key: String) {
        var query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: "com.sommlens.scanquota.count",
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)

        var value = count
        let data = Data(bytes: &value, count: MemoryLayout<Int>.size)
        query[kSecValueData] = data

        SecItemAdd(query as CFDictionary, nil)
    }
    
    // Used in getScanCount - loads count
    static func loadCount(for key: String) -> Int? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: "com.sommlens.scanquota.count",
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              data.count == MemoryLayout<Int>.size
        else { return nil }

        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }
    
    // Either loads userID connected to user or creates a new ID the first load
    static func loadOrCreateAppUserID() -> String {
           // 1) try to load
           let query: [CFString: Any] = [
               kSecClass:       kSecClassGenericPassword,
               kSecAttrService: rcService,
               kSecAttrAccount: rcAccount,
               kSecReturnData:  true,
               kSecMatchLimit:  kSecMatchLimitOne
           ]
           var item: AnyObject?
           if  SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
               let data = item as? Data,
               let id   = String(data: data, encoding: .utf8) {
               return id
           }

           // 2) not found → create & save
           let id   = UUID().uuidString
           let data = id.data(using: .utf8)!
           var add  = query
           add[kSecValueData] = data
           SecItemAdd(add as CFDictionary, nil)
           return id
       }
}
