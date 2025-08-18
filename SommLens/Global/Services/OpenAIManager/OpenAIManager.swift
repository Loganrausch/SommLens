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
        guard let jpeg = resized.jpegData(compressionQuality: 0.7) else {
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

    
    
    // MARK: - WineData ➜ AITastingProfile - ForAITastingFeature
    
    func tastingProfile(for wine: WineData) async throws -> AITastingProfile {

        // 1️⃣  Pulling the 10 × 10 descriptor pools straight from the enum - same descriptors the user will have.
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
        
        // Using async/await variant of `postJSON`
        let content = try await postJSON(body, to: chatEndpoint)
        var profile: AITastingProfile = try decodeJSON(content)

          // LOCAL FALLBACK  – decide if the style itself implies tannin
          let styleImpliesTannin = wine.category.tanninExists
       
          // MERGE LOGIC  – keep GPT’s answer, but force ‘true’ for red/orange styles
          profile.hasTannin = profile.hasTannin || styleImpliesTannin
       
          return profile
       }
    
    // MARK: - PRIVATE helpers for AITastingFlow
    
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
    
   
    // Async/await POST (used by tastingProfile) - // Sends the actual HTTP request
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
