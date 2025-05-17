//
//  OpenAIManager.swift
//  SommLens
//
//  Created by ChatGPT on 11 May 2025
//

import Foundation
import Combine

// MARK: - Top‑level API manager
@MainActor
final class OpenAIManager: ObservableObject {
    
    // ---------- CONFIG ----------
    
    /// Your existing Vinobytes proxy (change if you talk to OpenAI directly)
    private let endpoint = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/api/chat")!
    
    /// If you call OpenAI directly, store your key in the environment and read it here
    private let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    
    // ---------- PUBLIC  OCR → WineData ----------
    
    /// Sends raw OCR text → GPT JSON → decodes into `WineData`
    func extractWineInfo(from ocrText: String,
                         completion: @escaping (Result<WineData, Error>) -> Void)
    {
        let systemPrompt = ocrSystemPrompt
        let userMessage  = ocrText
        
        let body = chatBody(
            model:  "gpt-4o",
            system: systemPrompt,
            user:   userMessage,
            temp:   0
        )
        
        postJSON(body, to: endpoint) { [weak self] result in
            switch result {
            case .success(let content):
                self?.decodeJSON(content, as: WineData.self, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // ---------- NEW  WineData → AITastingProfile (async) ----------
    
    // MARK: - WineData ➜ AITastingProfile  (uses explicit category)
    func tastingProfile(for wine: WineData) async throws -> AITastingProfile {

        // 1️⃣  Pull the 10 × 10 descriptor pools straight from the enum
        let aromaPool    = wine.category.aromaPool
        let flavourPool  = wine.category.flavourPool
        let aromasCSV    = aromaPool.joined(separator: ", ")
        let flavoursCSV  = flavourPool.joined(separator: ", ")

        // 2️⃣  Minimal system message
        let system = "You are a sommelier AI that returns ONLY valid JSON, no prose."
        
        let userPrompt = """
           Provide a concise CLASSIC tasting profile JSON for this wine:
           
           Producer: \(wine.producer ?? "Unknown")
           Region:   \(wine.region   ?? "Unknown")
           Grapes:   \(wine.grapes?.joined(separator: ", ") ?? "N/A")
           Vintage:  \(wine.vintage  ?? "NV")
           
           Choose exactly four aromas and exactly four flavours from the lists below.
           Pick the appropriate boolean for hasTannin. Use true if there’s noticeable grip, otherwise use false. 
           
           AllowedAromas:  \(aromasCSV)
           AllowedFlavors: \(flavoursCSV)

           Respond with exactly:
           {
             "acidity":"Low|Medium-|Medium|Medium+|High",
             "alcohol":"Low|Medium-|Medium|Medium+|High",
             "body":"Light|Medium-|Medium|Medium+|Full",
             "tannin":"Low|Medium-|Medium|Medium+|High",
             "sweetness":"Bone-Dry|Dry|Off-Dry|Sweet|Very Sweet",
             "aromas":[/* 4 from AllowedAromas */],
             "flavors":[/* 4 from AllowedFlavors */],
             "tips":["One short palate-training tip"],
             "hasTannin":<true|false>
           }
           """
        
        let body = chatBody(
            model: "gpt-4o",
            system: system,
            user:   userPrompt,
            temp:   0.3
        )
        
        // Use async/await variant of `postJSON`
        let content = try await postJSON(body, to: endpoint)
        return try decodeJSON(content, as: AITastingProfile.self)
    }
    
    // MARK: - PRIVATE helpers ---------------------------------------------------
    
    private var ocrSystemPrompt: String {
        #"""
        ROLE
        You are an expert sommelier-extractor.
        Return only valid double-quoted JSON—no markdown, no code fences, no comments.

        ──────────────────── PHASE 1 – PRE-CLEAN
        • Fix obvious OCR typos in producer/region names.  
        • Restore accents (Chateau → Château) and title-case proper nouns.

        ──────────────────── PHASE 2 – FIELD RULES
        VINTAGE  
          • Consider every 4-digit year 1900-to-(current year + 1).  
          • Reject it if the word immediately before it is “est.”, “established”, “since”,  
            “founded”, “bottled”, “produced”, or “imported”.  
          • Accept the first remaining year that matches ONE of:  
              ① directly after “vintage”, “harvest”, or “vendimia”  
              ② directly after a grape variety name or the word “Porto”  
              ③ appears on its own line or is the only year on the label  
          • If several years qualify, choose the most recent one ≤ current year.  
          • If no year qualifies, output "vintage":"NV".

        GRAPES  
          • Use the exact varieties printed on the label.  
          • If multiple varieties are listed, return them all in order.
          • If the bottle does not list grapes on the label, use the producer, region, country and vineyard to infer.
          • If none are verifiable, return "Red Blend" or "White Blend".

        CATEGORY  
          Infer from grapes + tasting notes; choose ONE:  
          red wine | white wine | rosé wine | red sparkling wine | white sparkling wine |  
          red dessert wine | white dessert wine | red fortified wine | white fortified wine | orange wine.

        PAIRINGS Exactly three concise dishes/items.  
        VIBETAG  ≤ 8 words.

        ──────────────────── RETURN JSON IN THIS KEY ORDER
        {
          "producer": "",
          "region": "",
          "country": "",
          "grapes": [],
          "vintage": "",
          "classification": null,
          "tastingNotes": "",
          "pairings": ["", "", ""],
          "vibeTag": "",
          "vineyard": null,
          "soilType": null,
          "climate": null,
          "drinkingWindow": null,
          "abv": null,
          "winemakingStyle": null,
          "category": ""
        }

        GENERAL CONSTRAINTS  
        1. Arrays stay arrays even with one item.  
        2. Leave a field null only when no reliable information exists.  
        3. Infer soilType, climate, drinkingWindow, winemakingStyle when typical for the region/vintage.  
        4. Do not output any extraneous keys, prose, or markdown.
        """#
        
        
    }
    
    // Build the standard chat body
    private func chatBody(model: String,
                          system: String,
                          user: String,
                          temp: Double) -> [String: Any]
    {
        [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": user]
            ],
            "temperature": temp
        ]
    }
    
    // MARK: – Networking
    
    /// *Completion‑handler* POST (used by OCR call)
    private func postJSON(_ json: [String: Any],
                          to url: URL,
                          completion: @escaping (Result<String, Error>) -> Void)
    {
        guard let httpBody = try? JSONSerialization.data(withJSONObject: json) else {
            completion(.failure(NSError(domain: "", code: -11, userInfo: [NSLocalizedDescriptionKey: "Bad JSON body"])))
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = httpBody
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = openAIKey { req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let data = data, let top = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                  let content = top.choices.first?.message.content
            else {
                completion(.failure(NSError(domain: "", code: -12, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(content))
        }
        .resume()
    }
    
    /// *Async/await* POST (used by tastingProfile)
    private func postJSON(_ json: [String: Any], to url: URL) async throws -> String {
        let data = try JSONSerialization.data(withJSONObject: json)
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = data
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = openAIKey { req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        
        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let top = try JSONDecoder().decode(OpenAIResponse.self, from: respData)
        guard let content = top.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        return content
    }
    
    // sync variant
    private func decodeJSON<T: Decodable>(_ jsonString: String,
                                          as type: T.Type,
                                          completion: @escaping (Result<T, Error>) -> Void)
    {
        let trimmed = cleanJSON(jsonString)
        
        #if DEBUG
        print("── AI raw jsonString ──\n\(jsonString)\n── trimmed ──\n\(trimmed)")
        #endif
        
        do {
            let data = Data(trimmed.utf8)
            let obj  = try JSONDecoder().decode(T.self, from: data)
            completion(.success(obj))
        } catch {
            completion(.failure(error))
        }
    }

    // async variant
    private func decodeJSON<T: Decodable>(_ jsonString: String, as type: T.Type) throws -> T {
        let trimmed = cleanJSON(jsonString)
        
        #if DEBUG
        print("── AI raw jsonString ──\n\(jsonString)\n── trimmed ──\n\(trimmed)")
        #endif
        
        let data = Data(trimmed.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Remove ```json fences / extra back‑ticks & trim whitespace.
private func cleanJSON(_ raw: String) -> String {
    raw.replacingOccurrences(of: "```json", with: "")
       .replacingOccurrences(of: "```",     with: "")
       .trimmingCharacters(in: .whitespacesAndNewlines)
}
