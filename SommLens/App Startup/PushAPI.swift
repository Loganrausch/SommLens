//
//  PushAPI.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//
import Foundation

enum PushAPI {

    /// Registers an APNs token for SommLens with your Heroku server
    static func register(token: String) {

        // 1. Build the JSON payload
        let json: [String: String] = [
            "deviceToken": token,
            "app": "SOMMLENS"
        ]

        // 2. Prepare URL and HTTP body
        guard
            let url  = URL(string: "https://vinobytes-afe480cea091.herokuapp.com/registerDevice"),
            let body = try? JSONSerialization.data(withJSONObject: json)
        else { return }

        // 3. Fire‐and‐forget request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request).resume()
    }
}
