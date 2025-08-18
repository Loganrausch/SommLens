//
//  JSONHelpers.swift
//  SommLens
//
//  Created by Logan Rausch on 6/30/25.
//

import Foundation

func decodeJSON<T: Decodable>(_ jsonString: String) throws -> T {
    let trimmed = cleanJSON(jsonString)
    #if DEBUG
    print("── AI raw jsonString ──\n\(jsonString)\n── trimmed ──\n\(trimmed)")
    #endif
    let data = Data(trimmed.utf8)
    return try JSONDecoder().decode(T.self, from: data)
}


func cleanJSON(_ raw: String) -> String {
raw.replacingOccurrences(of: "```json", with: "")
   .replacingOccurrences(of: "```",     with: "")
   .trimmingCharacters(in: .whitespacesAndNewlines)
}
