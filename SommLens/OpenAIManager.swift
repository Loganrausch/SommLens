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
    
    /// Builds a concise prompt from `WineData`, returns a classic profile in JSON.
    func tastingProfile(for wine: WineData) async throws -> AITastingProfile {
        let system = """
        You are a sommelier AI that returns ONLY valid JSON, no prose.
        """
        
        let userPrompt = """
        Provide a concise CLASSIC tasting profile JSON for this wine:

        Producer: \(wine.producer ?? "Unknown")
        Region:   \(wine.region   ?? "Unknown")
        Grapes:   \(wine.grapes?.joined(separator: ", ") ?? "N/A")
        Vintage:  \(wine.vintage  ?? "NV")

        Respond with exactly:
        {
          "acidity":"Low|Medium-|Medium|Medium+|High",
          "alcohol":"Low|Medium-|Medium|Medium+|High",
          "body":"Light|Medium-|Medium|Medium+|Full",
          "tannin":"Low|Medium-|Medium|Medium+|High",
          "sweetness":"Bone-Dry|Dry|Off-Dry|Sweet|Very Sweet",
          "aromas":["Cherry","Rose", "..."],
          "tips":["One short palate‑training tip"]
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
        """
        You are an expert sommelier and spell‑checker.

        TASK A — PRE‑CLEAN TEXT
        • Correct obvious OCR typos in well‑known winery / region names
          (e.g. “Gacomo Conterno” → “Giacomo Conterno”).
        • Normalise accents (Chateau → Château) and capitalisation.

        TASK B — RETURN EXACTLY THIS JSON SCHEMA
        {
          "producer":"<string>",
          "region":"<string>",
          "country":"<string>",
          "grapes":["<string>", …],
          "vintage":"<string|null>",
          "classification":"<string|null>",
          "tastingNotes":"<string>",
          "pairings":["<string>", "<string>", "<string>"],
          "vibeTag":"<≤8 words>",
          "vineyard":"<string|null>",
          "soilType":"<string|null>",
          "climate":"<string|null>",
          "drinkingWindow":"<string|null>",
          "abv":"<string|null>",
          "winemakingStyle":"<string|null>"
        }

        RULES
        1. "Do not hallucinate grapes. If unsure, use ‘Red Blend’ or 'White Blend', but if typical grapes are clearly implied (e.g., Barolo = Nebbiolo), fill them in confidently."
        2. Output ONLY double‑quoted JSON, no markdown.
        3. Preserve key order exactly.
        4. Arrays must be valid JSON arrays even if only one element.
        5. Keep vibeTag to eight words or fewer.
        6. Use the region or vineyard to infer soil type & climate.
        7. Leave fields blank ONLY if truly no information is available.
        8. Infer drinking window from vintage and typical aging potential of the region if needed.
        9. Use producer information to determine winemaking style if needed.
        """
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
