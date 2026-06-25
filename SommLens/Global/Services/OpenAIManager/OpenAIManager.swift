//
//  OpenAIManager.swift
//  SommLens
//

// Refactored by Logan Rausch on July 15th, 2025

// Network calls still happen off-main despite @MainActor. We ensure that before touching any UI state we hop back on the main.



import Foundation
import UIKit

// MARK: - Top-level API manager for SommLens scan extraction
@MainActor
final class OpenAIManager: ObservableObject {
    
    // ---------- CONFIG ----------
    
    // Temporary mock Lambda scan endpoint for Phase 1 JSON integration.
    private let imageEndpoint = URL(string: "https://fwega5yvce.execute-api.us-east-1.amazonaws.com/default/sommlens-scan-mock")!
    
    
    
    
    // MARK: - UIImage → WineData - MainScanFlow
    func extractWineInfo(
        from image: UIImage,
        completion: @escaping (Result<WineData, Error>) -> Void
    ) {
        let url          = imageEndpoint

        // 2️⃣ Resize + JPEG-encode image (576 px, Q 0.7) ----------------------------
        let resized  = image.resized(maxEdge: 576)
        guard let jpeg = resized.jpegData(compressionQuality: 0.9) else {
            return completion(.failure(
                NSError(domain: "OpenAIManager", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"]))
            )
        }

        // 3️⃣ Build JSON request for Lambda scan endpoint ---------------------------
        let payload: [String: String] = [
            "imageBase64": jpeg.base64EncodedString(),
            "detail": "low"
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return completion(.failure(
                NSError(domain: "OpenAIManager", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to serialize scan payload"]))
            )
        }

        // 4️⃣ Fire request ----------------------------------------------------------
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody   = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // ⏱ Timeout after 15 seconds
        let session = URLSession(configuration: config)

        // Sends the actual HTTP request
        session.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("❌ Network or timeout error:", err.localizedDescription)
                return completion(.failure(err))
            }

            guard let d = data else {
                return completion(.failure(
                    NSError(domain: "", code: -12,
                            userInfo: [NSLocalizedDescriptionKey: "Missing response data"]))
                )
            }

            // 5️⃣ Decode direct WineData JSON w/ thread safety
            do {
                let wine = try JSONDecoder().decode(WineData.self, from: d)
                DispatchQueue.main.async { completion(.success(wine)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            
            }
        }
        .resume()
    }
}
