//
//  OpenAIManager.swift
//  SommLens
//
//  Created by Logan Rausch on 4/17/25.
//

import Foundation
import Combine

class OpenAIManager: ObservableObject {
    /// Point this at your existing Vinobytes proxy
    private let endpoint = "https://vinobytes-afe480cea091.herokuapp.com/api/chat"

    /// Sends raw OCR text to your proxy, reads back the GPT JSON blob, then decodes WineData.
    func extractWineInfo(from ocrText: String,
                         completion: @escaping (Result<WineData, Error>) -> Void)
    {
        let systemPrompt = """
        You are an expert sommelier and spell‑checker.

        TASK A — PRE‑CLEAN TEXT
        • Correct obvious OCR typos in well‑known winery / region names
          (e.g. “Gacomo Conterno” → “Giacomo Conterno”).
        • Normalise accents (Chateau → Château) and capitalisation (all Title‑Case).

        TASK B — RETURN EXACTLY THIS JSON SCHEMA
        {
          "producer":        "<string>",
          "region":          "<string>",
          "country":         "<string>",
          "grapes":          ["<string>", …],      // always an array
          "vintage":         "<string|null>",      // “NV” or null if non‑vintage
          "classification":  "<string|null>",      // DOCG, Premier Cru, etc.
          "tastingNotes":    "<string>",           // 1–2 elegant sentences
          "pairings":        ["<string>", "<string>", "<string>"], // exactly 3
          "vibeTag":         "<≤8 words>"          // e.g. “Great for Cozy night in”
          "vineyard":         "<string|null>",         // e.g. “Clos Saint-Jacques”
          "soilType":         "<string|null>",         // e.g. “Granite, clay-limestone”
          "climate":          "<string|null>",         // e.g. “Cool continental”
          "drinkingWindow":   "<string|null>",         // e.g. “2025–2035”
          "abv":              "<string|null>",         // e.g. “13.5%”
          "winemakingStyle":  "<string|null>"          // e.g. “12 months in neutral oak”
        }

        RULES
        1. Do not guess grapes based on region/producer context. Return grapes if positive they are correct for the vintage and producer. If really unsure, return "Red Blend" or "White Blend".
        2. Use **double‑quoted JSON** only — no markdown, no code fences, no comments.
        3. Preserve key order exactly as above.
        4. Arrays must be valid JSON arrays even if only one element.
        5. Keep vibeTag to eight words or fewer.
        6. Use the region and/or vineyard location to determine the soil type and climate.

        """
        let userMessage = ocrText
        
        // Build the same chat‑style body you’d send to OpenAI
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userMessage]
            ],
            "temperature": 0
        ]
        
        // 1) Serialize
        guard let url = URL(string: endpoint),
              let httpBody = try? JSONSerialization.data(withJSONObject: body)
        else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
            return
        }
        
        // 2) Make the request
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = httpBody
        
        // 3) Fire
        URLSession.shared.dataTask(with: req) { data, response, error in
            // 1) Transport error
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            // 2) HTTP status check
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let err = NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey: "Bad status \(code)"])
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }
            // 3) Data presence
            guard let data = data else {
                let err = NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data"])
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }
            // 4) Decode proxy wrapper
            do {
                let topLevel = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                let content = topLevel.choices.first?.message.content ?? ""
                #if DEBUG
                print("OpenAI raw content:", content)
                #endif
                guard let jsonData = content.data(using: .utf8) else {
                    throw NSError(domain: "", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
                }
                let wine = try JSONDecoder().decode(WineData.self, from: jsonData)
                DispatchQueue.main.async { completion(.success(wine)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        .resume()
    }
}
