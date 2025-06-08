//
//  PushManager.swift
//  SommLens
//
//  Created by Logan Rausch on 6/3/25.
//

import UIKit
import UserNotifications

// A single notification key that SwiftUI can observe
extension Notification.Name {
    static let pushPromptFinished = Notification.Name("pushPromptFinished")
}

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // 1️⃣ Ask for push permission immediately
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in

                if granted {
                    // If the user allowed, register with APNs
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }

                // 2️⃣ No matter what they chose, notify SwiftUI the sheet is gone
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .pushPromptFinished, object: nil)
                }
            }
        return true
    }

    // --------------------------------------------------------------------
    // APNs callbacks
    // --------------------------------------------------------------------

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNs token (SommLens): \(token)")
        PushAPI.register(token: token)          // send to your server
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs registration failed:", error.localizedDescription)
    }
}
