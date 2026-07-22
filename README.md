<div align="center">
  <!-- Replace this with a link to your 1024x1024 app icon -->
  <img src="https://github.com/user-attachments/assets/e864cbd6-9de3-4d7f-b174-d4806f41bc74" alt="Simple Store Logo" width="120" height="120">

  # Simple Store
  
  **A sleek, native Point of Sale and inventory management system for iOS.**

  ---
  
  <!-- App Store style horizontal scrolling screenshots -->
  <p align="center">
    <img src="https://github.com/user-attachments/assets/1f6fe7f0-a2ca-4a67-9c6a-53ee5342a83f" width="200">&nbsp;&nbsp;&nbsp;&nbsp;
    <img src="https://github.com/user-attachments/assets/c48bcf36-af23-4568-8146-41222321e254" width="200">&nbsp;&nbsp;&nbsp;&nbsp;
    <img src="https://github.com/user-attachments/assets/81b30665-0e31-43f9-808f-1170a303f158" width="200">&nbsp;&nbsp;&nbsp;&nbsp;
    <img src="https://github.com/user-attachments/assets/f6eeaa19-628f-4076-b161-2949bbbd8b39" width="200">
  </p>
</div>

## 📦 About The App
Simple Store transforms your iPhone into a powerful, offline-first retail terminal. Designed with a focus on speed, fluid gestures, and native iOS aesthetics, it handles everything from dynamic cart splitting to custom PDF receipt generation without requiring an internet connection.

## ✨ Key Features
*   **🛒 Frictionless Checkout:** A smart cart system with multi-tender payment splitting (Cash, Card, E-Transfer).
*   **📦 Inventory Management:** Track stock levels, assign custom color-coded tags, and manage items with a built-in barcode scanner.
*   **🧾 Custom PDF Receipts:** Automatically generate, view, and share branded PDF receipts natively via the iOS Share Sheet.
*   **👥 Directory System:** Manage customer profiles and employee PINs to track exactly who processed which transaction.
*   **⚡️ Offline First:** Powered entirely by a local database, ensuring your store operations never go down.

## 🛠️ Tech Stack
*   **Framework:** SwiftUI
*   **Database:** SwiftData (Local persistence)
*   **Rendering:** CoreGraphics & PDFKit (Receipt generation)
*   **Hardware:** AVFoundation (Barcode scanning)

## 🚀 Installation & Build
To run Simple Store locally on your device or simulator:
1. Clone this repository: `git clone https://github.com/yourusername/SimpleStore.git`
2. Open `Simple_Inventory.xcodeproj` in **Xcode 15+**.
3. Navigate to the **Signing & Capabilities** tab and select your Personal Development Team.
4. Select your target iOS device and hit **Run (Cmd + R)**.
