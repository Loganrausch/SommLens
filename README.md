

# 🍷 SommLens

**SommLens** is a premium iOS app that combines Artificial Intelligence, live camera scanning, and sommelier-level tasting guidance to make wine more approachable, educational, and fun.

Crafted by a Certified Sommelier and built with SwiftUI, Core Data, and the OpenAI API, SommLens decodes any wine label in seconds and guides users through a professional-level tasting — even if they’re brand new to wine.

---
## ✨ Screenshots
<p align="center">
  <img src="https://github.com/user-attachments/assets/20cb3e1e-d643-44d2-a847-2d94209cac8b" width="150"/>
  <img src="https://github.com/user-attachments/assets/0b45bca7-6356-4889-b27e-41c67ff1a80b" width="150"/>
  <img src="https://github.com/user-attachments/assets/d05ccb8b-0cd4-4dfd-9f65-1adbe8547c43" width="150"/>
  <img src="https://github.com/user-attachments/assets/69ff3ff3-87c3-487e-91dc-29d6b2e5657c" width="150"/>
  <img src="https://github.com/user-attachments/assets/cd3b0282-e087-461c-a191-5357d9783a49" width="150"/>
</p>

## 📸 Features

### 1. Live Wine Label Scanning
- Powered by `AVCaptureSession` and a real-time video buffer for smooth previews.
- Tap the shutter to freeze the label and capture a high-res image, securely uploaded to Heroku and processed by OpenAI — then immediately deleted.
- Extracts structured wine data including grape variety, region, vintage, producer, soil type, climate, and more.
- Immersive UI: vertical shimmer animation, animated wineglass loader, and elegant transitions.

### 2. Scan Limits & Subscription
- Free users receive 10 lifetime scans.
- Pro users unlock 200 scans per month.
- RevenueCat integration for paywall, entitlement syncing, and auto-restore.
- Scan limits are enforced with user-friendly alerts and persist across reinstalls using Keychain.

### 3. Guided AI Tastings
- Structured tasting flow: acidity, alcohol, tannin, body, sweetness, aromas, flavors, and summary.
- Compare your impressions with *Vini* — the AI-generated classic tasting profile.
- Clean animations, intuitive sliders, and responsive toggles enhance interaction.

### 4. Taste Later Workflow
- Scan now, taste later. Wines appear in “My Wines” with a “Taste this wine” call-to-action.
- Once completed, they transition to “You tasted this wine!” with structured recall data.

### 5. Thoughtful UI & Experience
- Large central bottle-scan button welcomes users upon launch.
- Elegant shadows, custom color palette, and smooth transitions throughout.
- Filter wines by category (red, white, rosé, orange, and more).
- Tactile feedback and refined iconography make every interaction satisfying.

---

## 🛠 Technologies Used
- **SwiftUI** — modern, declarative interface
- **Core Data** — offline scan storage
- **CloudKit** — syncs scans across devices and reinstalls
- **OpenAI API** — label recognition + AI tasting profiles
- **AVFoundation** — live camera + high-res capture
- **RevenueCat** — subscription management and entitlements
- **Contentful** — dynamic push content + delivery
- **Heroku** — transient image hosting + API endpoints

---

## 👨‍💻 Development Notes
- SommLens follows a modular MVVM architecture for most views: dashboards, tasting flows, and scan history.
- The scanning system avoids MVVM to preserve full control over `AVCaptureSession` lifecycle and real-time state.
- Re-selecting the scan tab resets state to ensure fresh camera config and prevent stale references.
- Vertical shimmer, frozen overlays, and animated transitions are coordinated directly in `MainScanView`.
- Scan usage is tracked via Keychain to survive deletions and prevent free-tier abuse.
- A real-time buffer delegate freezes the frame immediately while a high-res image is sent to OpenAI for decoding.

---

## 📂 Project Structure

- `AccountSettings` — Handles user preferences, contact forms, and account-related views
- `AITastingFlow` — Guided tasting interface with user input and AI comparison
- `AppStartup` — Launch screen and initial root view configuration
- `Dashboard` — Displays scan limits, recent wines, and educational scan tips
- `Global` — Shared state and services (engagement tracking, persistence, RevenueCat, OpenAI, and wine data)
- `MyScans` — Scan history, wine detail views, and tasting recall
- `Scanning` — Camera session, image capture, overlay animations, and AI processing

---

## 🔐 Privacy
SommLens does not collect personal data. All image analysis is handled locally or via secure API. Scans are saved only when explicitly stored.

---

## 🙌 Credits
- Created by a Certified Sommelier with a passion for wine education and technology  
- Inspired by WSET & CMS tasting frameworks  
- Icons via SF Symbols, animations crafted in SwiftUI  

---

## 📦 Future Improvements
- **Favorites** — Save wines you love for fast access and comparison  
- **Wine-Specific AI Chat** — Ask questions about any scanned wine (e.g. food pairings, cellaring)  
- **Interactive Wine Map** — Browse wine styles by region, climate, or grape  
- **Scan Streaks & Achievements** — Track progress and earn tasting milestones  

---

Thanks for checking out SommLens! 🍷  
