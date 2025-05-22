//
//  OpenAIManager.swift
//  SommLens
//
//  Created by ChatGPT on 11 May 2025
//

import Foundation
import UIKit

// MARK: - Top‑level API manager
@MainActor
final class OpenAIManager: ObservableObject {
    
    // ---------- CONFIG ----------
    
    private let chatEndpoint  = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/api/chat")!
    private let imageEndpoint = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/api/chat/image")!
    
    /// If you call OpenAI directly, store your key in the environment and read it here
    private let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    
    // ---------- PUBLIC  OCR → WineData ----------
    
    /// Sends a raw JPEG of the wine label → GPT JSON → decodes into `WineData`
    func extractWineInfo(
      from image: UIImage,
      completion: @escaping (Result<WineData, Error>) -> Void
    ) {
      let systemPrompt = imageSystemPrompt
      let url = imageEndpoint

      // 1️⃣ Build and JSON-encode the messages array
      let messagesArray: [[String: String]] = [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content":
         "This is a photo of a wine label. Extract all structured wine information you can — including producer, region, vintage, grapes, classification, and any other known facts. Use your own vast knowledge of the wine world to complete missing details if they are not clearly printed on the label."]
      ]
      
      guard let jsonMessages = try? JSONSerialization.data(withJSONObject: messagesArray) else {
        return completion(.failure(
          NSError(domain: "OpenAIManager", code: -2,
                  userInfo: [NSLocalizedDescriptionKey: "Failed to serialize messages"])
        ))
      }

      // 2️⃣ Convert image to JPEG
      guard let jpeg = image.jpegData(compressionQuality: 0.8) else {
        return completion(.failure(
          NSError(domain: "OpenAIManager", code: -1,
                  userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"])
        ))
      }

      // 3️⃣ Create multipart/form-data body
      let boundary = "Boundary-\(UUID().uuidString)"
      var body = Data()
      body.appendString("--\(boundary)\r\n")
      body.appendString("Content-Disposition: form-data; name=\"messages\"\r\n")
      body.appendString("Content-Type: application/json\r\n\r\n")
      body.append(jsonMessages)
      body.appendString("\r\n")

      body.appendString("--\(boundary)\r\n")
      body.appendString("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n")
      body.appendString("0\r\n")

      body.appendString("--\(boundary)\r\n")
      body.appendString("Content-Disposition: form-data; name=\"max_tokens\"\r\n\r\n")
      body.appendString("1024\r\n")

      body.appendString("--\(boundary)\r\n")
      body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"label.jpg\"\r\n")
      body.appendString("Content-Type: image/jpeg\r\n\r\n")
      body.append(jpeg)
      body.appendString("\r\n")
      body.appendString("--\(boundary)--\r\n")

      // 4️⃣ Configure the request
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      req.httpBody = body
      req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

      // 5️⃣ Send request
      URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err = err {
          return completion(.failure(err))
        }
        guard let d = data,
              let full = try? JSONDecoder().decode(OpenAIResponse.self, from: d),
              let content = full.choices.first?.message.content else {
          return completion(.failure(
            NSError(domain: "", code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
          ))
        }

        // 🧮 6️⃣ Log token usage & cost estimate
        let usage = full.usage
        let promptTokens     = Double(usage.prompt_tokens)
        let completionTokens = Double(usage.completion_tokens)
        let imageCost        = 0.00765 // Approx. cost for a ~512x512 JPEG

        let inCost  = promptTokens     / 1000 * 0.005   // text input
        let outCost = completionTokens / 1000 * 0.015   // text output

        print("🧮 Tokens: prompt=\(Int(promptTokens)), completion=\(Int(completionTokens)), total=\(Int(usage.total_tokens))")
        print(String(format: "💵 Estimated cost: In=$%.5f, Out=$%.5f, Image=$%.5f → Total=$%.5f",
                     inCost, outCost, imageCost, inCost + outCost + imageCost))

        // 7️⃣ Decode into WineData
        self.decodeJSON(content, as: WineData.self, completion: completion)
      }.resume()
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
        
        var body = chatBody(
               model:  "gpt-4o",
               system: system,
               user:   userPrompt,
               temp:   0.3
           )

           // ← And here:
           body["max_tokens"] = 512   // or whatever limit you prefer
        
        // Use async/await variant of `postJSON`
        let content = try await postJSON(body, to: chatEndpoint)
        return try decodeJSON(content, as: AITastingProfile.self)
    }
    
    // MARK: - PRIVATE helpers ---------------------------------------------------
    
    private var imageSystemPrompt: String {
        #"""
            You are a sommelier-AI that extracts structured data from wine label images and supplements missing details using your global wine knowledge.

            I will provide you a JPEG image of a wine label. You must return only valid double-quoted JSON — no markdown, prose, or explanations.

            Use the label image to identify key facts. If any detail is not visible on the label but you can reliably infer it from your vast wine knowledge (based on producer, region, classification, vineyard, vintage), then you should include it.

            Leave a field `null` or `""` only if it cannot be found on the label AND cannot be inferred reliably.

            ──────────────────────── RETURN JSON IN THIS KEY ORDER:
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

            ──────────────────────── FIELD HINTS

            • "classification": e.g., DOC, DOCG, AOC, AVA — if shown or inferable from region.
            • "tastingNotes should always filled out, use grape varities and region to determine.
            • "pairings": 3 short food matches (not general cuisines).
            • "vibeTag": max 10 words, emotional tone.
            • "soilType": e.g., clay-limestone, volcanic — use known terroirs.
            • "climate": e.g., Mediterranean, continental, maritime.
            • "drinkingWindow": e.g., "2022–2035" if wine is ageworthy.
            • "winemakingStyle": e.g., traditional, natural, Bordeaux-style, oxidative.
            • "category": Must choose from:
              - red wine | white wine | rosé wine | orange wine
              - red sparkling wine | white sparkling wine
              - red dessert wine | white dessert wine
              - red fortified wine | white fortified wine

            DO NOT output any explanation, markdown, prose, or extra fields. Return pure JSON.
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
    
    /// *Completion‐handler* POST (used by extractWineInfo)
    private func postJSON(
      _ json: [String: Any],
      to url: URL,
      completion: @escaping (Result<String, Error>) -> Void
    ) {
      guard let httpBody = try? JSONSerialization.data(withJSONObject: json) else {
        completion(.failure(NSError(domain: "", code: -11,
          userInfo: [NSLocalizedDescriptionKey: "Bad JSON body"])))
        return
      }
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      req.httpBody = httpBody
      req.addValue("application/json", forHTTPHeaderField: "Content-Type")
      if let key = openAIKey {
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      }

      URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err = err {
          completion(.failure(err)); return
        }
        guard let data = data,
              let full = try? JSONDecoder().decode(OpenAIResponse.self, from: data)
        else {
          completion(.failure(NSError(domain: "", code: -12,
            userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
          return
        }

        // ── 1) Log token usage & cost estimate ──
        let u = full.usage
        let inCost  = Double(u.prompt_tokens)     / 1000 * 0.0015
        let outCost = Double(u.completion_tokens) / 1000 * 0.0020
        print("🧮 Tokens (callback): prompt=\(u.prompt_tokens) completion=\(u.completion_tokens) total=\(u.total_tokens)")
        print(String(format: "💵 Cost (callback): $%.6f in / $%.6f out = $%.6f total", inCost, outCost, inCost+outCost))

        // ── 2) Pass only the content string forward ──
        completion(.success(full.choices.first!.message.content))
      }
      .resume()
    }
    
    
    /// *Async/await* POST (used by tastingProfile)
    private func postJSON(_ json: [String: Any], to url: URL) async throws -> String {
      let data = try JSONSerialization.data(withJSONObject: json)
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      req.httpBody = data
      req.addValue("application/json", forHTTPHeaderField: "Content-Type")
      if let key = openAIKey {
        req.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      }

      let (respData, resp) = try await URLSession.shared.data(for: req)
      guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
      }

      let full = try JSONDecoder().decode(OpenAIResponse.self, from: respData)

      // ── 1) Log token usage & cost estimate ──
      let u = full.usage
      let inCost  = Double(u.prompt_tokens)     / 1000 * 0.0015
      let outCost = Double(u.completion_tokens) / 1000 * 0.0020
      print("🧮 Tokens (async): prompt=\(u.prompt_tokens) completion=\(u.completion_tokens) total=\(u.total_tokens)")
      print(String(format: "💵 Cost (async): $%.6f in / $%.6f out = $%.6f total", inCost, outCost, inCost+outCost))

      // ── 2) Return only the content ──
      return full.choices.first!.message.content
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


fileprivate extension Data {
  mutating func appendString(_ string: String) {
    if let d = string.data(using: .utf8) {
      append(d)
    }
  }
}
