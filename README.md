# ⚡ ZYNC — Portable WiFi Security Scanner

**ZYNC** is a portable IoT device powered by an **ESP32 microcontroller** that scans nearby WiFi networks and identifies potential security risks. It is paired with an **Android mobile app** (built using Flutter) to offer extended features such as log sync, export, and Bluetooth connectivity.

---

## 🎯 Project Objective

To provide non-technical users with a simple, fast, and portable way to assess WiFi network security and avoid risky connections — improving personal cybersecurity awareness.

---

## 📱 Key Features

### 🛠 ESP32 Hardware Module
- Real-time WiFi scanning
- Displays:
  - 📶 SSID (WiFi name)
  - 📡 Signal Strength (RSSI)
  - 🔐 Encryption Type (Open, WEP, WPA, WPA2)
  - ⚠️ Risk Level (Secure, Weak, Insecure)
- OLED display output
- Control buttons for UI navigation
- Battery-powered & portable
- Visual alerts for insecure networks

### 📲 ZYNC Android App
- Built with **Flutter**
- Connects to ESP32 via **Bluetooth**
- Features:
  - Live scan sync
  - View & manage WiFi scan logs
  - Export logs as PDF/CSV
  - Show risk explanations for non-tech users

---

## 🧰 Tech Stack

| Category           | Tools Used                                 |
|--------------------|---------------------------------------------|
| Microcontroller     | ESP32 (ESP-WROOM-32)                        |
| Display             | OLED 0.96" I2C Display                     |
| Power Supply        | 18650 Li-ion Battery + TP4056 + Switch     |
| App Front-End       | Flutter (Dart)                             |
| App Back-End        | FastAPI (for optional sync/log APIs)       |
| Communication       | Bluetooth (Serial over BT)                 |
| App Database        | SQLite                                     |
| Dev Tools           | Git, GitHub, Cursor Editor, VS Code        |

---

## 🔌 Components Required

- ESP32 Dev Board (ESP-WROOM-32)
- OLED Display (I2C)
- Tactile Push Buttons (2–3)
- TP4056 Charging Module
- 18650 Li-ion Battery + Holder
- Slide Power Switch
- 10KΩ Pull-down Resistors
- Jumper Wires, Breadboard / PCB
- (Optional) 3D Printed Case

---

## 🚀 Running the App

> Pre-requisites: Flutter SDK, Android Emulator or Device

```bash
git clone https://github.com/your-username/zync.git
cd zync/app
flutter pub get
flutter run
