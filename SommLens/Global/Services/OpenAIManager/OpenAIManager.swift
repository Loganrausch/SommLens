//
//  OpenAIManager.swift
//  SommLens
//

// Refactored by Logan Rausch on July 15th, 2025

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
    
    // MARK: - OCR: UIImage → WineData
    func extractWineInfo(
        from image: UIImage,
        completion: @escaping (Result<WineData, Error>) -> Void
    ) {
        let systemPrompt = imageSystemPrompt
        let url          = imageEndpoint

        // 1️⃣ Build messages payload ------------------------------------------------
        let messagesArray: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user",
             "content":
                "This is a photo of a wine label. Extract all structured wine information you can — including producer, region, vintage, grapes, classification, and any other known facts. Use your own vast knowledge of the wine world to complete missing details if they are not clearly printed on the label."]
        ]

        guard let jsonMessages = try? JSONSerialization.data(withJSONObject: messagesArray) else {
            return completion(.failure(
                NSError(domain: "OpenAIManager", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to serialize messages"]))
            )
        }

        // 2️⃣ Resize + JPEG-encode image (576 px, Q 0.7) ----------------------------
        let resized  = image.resized(maxEdge: 576)
        guard let jpeg = resized.jpegData(compressionQuality: 0.7) else {
            return completion(.failure(
                NSError(domain: "OpenAIManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"]))
            )
        }

        // 3️⃣ Build multipart/form-data --------------------------------------------
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func addField(name: String, value: String) {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString(value + "\r\n")
        }

        // messages JSON
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"messages\"\r\n")
        body.appendString("Content-Type: application/json\r\n\r\n")
        body.append(jsonMessages)
        body.appendString("\r\n")

        addField(name: "temperature", value: "0")
        addField(name: "max_tokens",  value: "350")     // ★ shorter completion
        addField(name: "detail",      value: "low")     // ★ vision detail low

        // the JPEG
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"image\"; filename=\"label.jpg\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpeg)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        // 4️⃣ Fire request ----------------------------------------------------------
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = body
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // ⏱ Timeout after 15 seconds
        let session = URLSession(configuration: config)

        session.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("❌ Network or timeout error:", err.localizedDescription)
                return completion(.failure(err))
            }

            guard
                let d = data,
                let full = try? JSONDecoder().decode(OpenAIResponse.self, from: d),
                let content = full.choices.first?.message.content
            else {
                return completion(.failure(
                    NSError(domain: "", code: -12,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                )
            }

            // 5️⃣ Log usage & cost --------------------------------------------------
            let usage = full.usage                          // not Optional
            let promptTokens     = Double(usage.prompt_tokens)
            let completionTokens = Double(usage.completion_tokens)
            let imageTokens      = Double(usage.image_tokens ?? 0)   // property is Optional

            let inCost    = promptTokens     / 1000 * 0.005          // text in
            let outCost   = completionTokens / 1000 * 0.015          // text out
            let imageCost = usage.image_tokens != nil
                ? Double(usage.image_tokens!) / 1000 * 0.005
                : estimateVisionCost(for: resized)        // fallback

            print("🧮 Tokens: prompt=\(Int(promptTokens)), completion=\(Int(completionTokens)), image=\(Int(imageTokens)), total=\(usage.total_tokens))")
            print(String(format: "💵 Estimated cost: In=$%.5f, Out=$%.5f, Image=$%.5f → Total=$%.5f",
                         inCost, outCost, imageCost, inCost + outCost + imageCost))

            // 6️⃣ Decode into WineData ---------------------------------------------
           decodeJSON(content, as: WineData.self, completion: completion)
        }
        .resume()
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
        body["max_tokens"] = 350        // ★ tighter cap
        body["response_format"] = ["type":"json_object"]  // ★ forces compact JSON
        
        // Use async/await variant of `postJSON`
        let content = try await postJSON(body, to: chatEndpoint)
        var profile = try decodeJSON(content, as: AITastingProfile.self)

          // LOCAL FALLBACK  – decide if the style itself implies tannin
          let styleImpliesTannin = wine.category.tanninExists
       
          // MERGE LOGIC  – keep GPT’s answer, but force ‘true’ for red/orange styles
          profile.hasTannin = profile.hasTannin || styleImpliesTannin
       
          return profile
       }
    
    // MARK: - PRIVATE helpers
    
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
}
