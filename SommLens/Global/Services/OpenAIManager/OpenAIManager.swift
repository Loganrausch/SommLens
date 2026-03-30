//
//  OpenAIManager.swift
//  SommLens
//

// Refactored by Logan Rausch on July 15th, 2025

// Network calls still happen off-main despite @MainActor. We ensure that before touching any UI state we hop back on the main.



import Foundation
import UIKit

// MARK: - Top‑level API manager for both AI calls in SommLens
@MainActor
final class OpenAIManager: ObservableObject {
    
    // ---------- CONFIG ----------
    
    private let chatEndpoint  = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/api/chat")!
    private let imageEndpoint = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/api/chat/image")!
  
    private let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    
    
    
    
    // MARK: - UIImage → WineData - MainScanFlow
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
        guard let jpeg = resized.jpegData(compressionQuality: 0.9) else {
            return completion(.failure(
                NSError(domain: "OpenAIManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"]))
            )
        }

        // 3️⃣ Build multipart/form-data - Formatting request into correct byte sequence
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

        // Sends the actual HTTP request
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

            // 5️⃣ Debug token counts
            #if DEBUG
            let u = full.usage
            print("🧮 Tokens: prompt=\(u.prompt_tokens), completion=\(u.completion_tokens), image=\(u.image_tokens ?? 0), total=\(u.total_tokens)")
            #endif

            // 6️⃣ Decode into WineData w/ thread safety
            do {
                let wine: WineData = try decodeJSON(content)
                DispatchQueue.main.async { completion(.success(wine)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            
            }
        }
        .resume()
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
    
   
    // Async/await POST- // Sends the actual HTTP request
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

        #if DEBUG
        let u = full.usage
        print("🧮 Tokens (async): prompt=\(u.prompt_tokens) completion=\(u.completion_tokens) total=\(u.total_tokens)")
        #endif

        guard let content = full.choices.first?.message.content else {
            throw URLError(.cannotDecodeRawData)
        }
        return content
    }
}

extension OpenAIManager {
    func assessWineRating(from wine: WineData) async throws -> AIRating {
        // 1) System prompt
        let system = """
        You are a sommelier-AI that returns ONLY valid JSON with no markdown or prose.
        Be concise, factual, and conservative when data are uncertain.
        """

        // 2) Encode the wine object we already extracted
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let wineJSONData = try? encoder.encode(wine)
        let wineJSON = wineJSONData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        #if DEBUG
        print("🔍================= AI RATING CALL =================")
        print("🍷 WINE_OBJECT JSON:")
        print(wineJSON)
        print("===================================================")
        #endif

        // 3) User prompt: core 4 factors
        let user = """
        Using ONLY the supplied wine object, assign a 0–100 quality rating and explain why in 2–4 sentences.
        Use classic region/village/producer heuristics if widely known; lower confidence only if key identity data \
        (producer, region, style) are missing or contradictory, NOT just because vintage is missing or NV.   // 🔹

        WINE_OBJECT:
        \(wineJSON)

        Return exactly this JSON shape:
        {
          "aiRating": 0,
          "ratingExplanation": "",
          "factors": [
            { "name":"style match","score":0,"weight":0.0,"reason":"" },
            { "name":"producer","score":0,"weight":0.0,"reason":"" },
            { "name":"terroir","score":0,"weight":0.0,"reason":"" },
            { "name":"craft","score":0,"weight":0.0,"reason":"" }
          ],
          "weightedTotal": 0,
          "confidence": 0.0
        }

        Factor semantics:
        • "style match": How true is this wine to its grape(s), style, and appellation.
        • "producer": Track record, house style, and consistency for this producer/estate.
        • "terroir": How clearly the site/region shows in structure, aroma profile, and texture.
        • "craft": Balance, structure, oak handling, texture, integration, and overall polish.

        Rules:
        • Scores are 0–100.
        • You MAY set the "weight" fields for your own internal math, but the client may re-weight them.
        • "weightedTotal" ≈ your internal Σ(score * weight), but the client may recompute.
        • "ratingExplanation": 2–4 sentences summarizing the why (mention vintage, value, ageworthiness here if relevant).
        • You may lower confidence if WINE_OBJECT is incomplete in core identity fields (producer, region, style),  
          but you MUST NOT lower confidence purely because the vintage is missing or the wine is non-vintage (NV). 

        Vintage & Non-Vintage:
        • NEVER penalize a wine solely for being non-vintage (NV) or missing a vintage field.
        • For explicitly non-vintage wines (e.g. "NV", "Non-Vintage", "N/V",
          or blank for styles commonly released as NV like Champagne and many sparkling wines):
          – Focus on house style, recent releases, style match, and craft.
          – Treat NV as normal for the category, not a quality concern.                                     
        • For wines with a specific vintage year:
          – You MAY mention vintage quality in the explanation, but it should be only one part of the reasoning, not the main driver.
        • You MUST NOT write phrases like "vintage is missing so reliability is lower";                       
          treat missing or NV vintage as neutral for the reliability / quality of the rating itself.         
        
        • Mass-market, high-volume, value brands (e.g. Barefoot, Yellow Tail,
          Sutter Home, Carlo Rossi, Cupcake, Apothic, etc.) can NEVER exceed 60.0 overall.
          Their style match may be high, but their craft, terroir, and complexity are limited.
        
        """

        // 4) Build body
        var body = chatBody(
            model:  "gpt-4o",
            system: system,
            user:   user,
            temp:   0.2
        )
        body["response_format"] = ["type": "json_object"]
        body["max_tokens"]      = 450

        #if DEBUG
        print("🧠 Sending rating request to OpenAI…")
        #endif

        // 5) Call API
        let content: String = try await postJSON(body, to: chatEndpoint)

        #if DEBUG
        print("🧠 RAW MODEL CONTENT STRING:")
        print(content)
        print("---------------------------------------------------")
        #endif

        let rawRating: AIRating = try decodeJSON(content)

        #if DEBUG
        print("✅ Decoded AIRating from model:")
        print("   aiRating: \(rawRating.aiRating)")
        print("   confidence: \(rawRating.confidence)")
        print("   weightedTotal (model): \(rawRating.weightedTotal ?? -1)")
        print("   factors:")
        for f in rawRating.factors {
            print("   • \(f.name) | score=\(f.score) | weight=\(f.weight) | reason=\(f.reason)")
        }
        print("---------------------------------------------------")
        #endif

        // 6) Apply app-side canonical weights and align math
        let appWeights: [String: Double] = [
            "style match": 0.20,   // ↓ less inflated
            "producer": 0.15,   // ↓ cheap brands shouldn't coast
            "terroir":  0.35,   // ↑ rewarding wines with originality
            "craft":    0.30    // ↑ punishes low-complexity sweet wines
        ]

        let aligned = rawRating.alignedToLocalMath(overridingWeights: appWeights)

        #if DEBUG
        print("📊 AFTER alignedToLocalMath(overridingWeights: appWeights):")
        print("   FINAL aiRating (ring): \(aligned.aiRating)")
        print("   FINAL weightedTotal:   \(aligned.weightedTotal ?? -1)")
        print("   FINAL factors (with app weights):")
        for f in aligned.factors {
            let wStr = String(format: "%.3f", f.weight)
            print("   • \(f.name) | score=\(f.score) | weight=\(wStr)")
        }
        print("🔚================= END AI RATING CALL =================\n")
        #endif

        return aligned
    }
}
