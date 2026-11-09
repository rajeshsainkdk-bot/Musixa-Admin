# 🎵 Musixa Platform - Indian Music Streaming & Community Ecosystem

Musixa is a state-of-the-art Android music streaming, offline audio, and community distribution ecosystem engineered in **Flutter** with a native Android Kotlin integration layer. It features a dual-APK architecture designed to empower listeners, creators, and platform administrators.

---

## 🌟 Dual-Application Ecosystem

| Application | Entry Point | Target Artifact | Primary Functions |
| :--- | :--- | :--- | :--- |
| **🎵 Musixa Player (User APK)** | `lib/main.dart` | `Musixa-Player-APK` | 17 bundled Indian tracks, 2-Step OTP onboarding, community upload screen, duplicate detection, and direct native APK sharing. |
| **🛡️ Musixa Admin (Admin APK)** | `lib/main_admin.dart` | `Musixa-Admin-APK` | Master PIN (`7777`) access, executive KPI cards, in-app audio preview moderation, and user directory CRM (Call, WhatsApp, Email). |

---

## 📚 Engineering & Architectural Library

The repository includes a dedicated documentation and QA library inside the [`library/`](library/) directory:

- 📄 **[Business Requirements Document (BRD)](library/brd/BRD_DOCUMENT_Musixa_PLATFORM.md)**: Product vision, user personas, functional requirements (FR-01 to FR-15), NFRs, and cloud roadmap.
- 🛠️ **[Technical Architecture & Theoretical Spec](library/technical/TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md)**: Module architecture, duplicate detection math, FileProvider native implementation, state machines, and CI/CD pipelines.
- 🧪 **[QA Test Suite & Manual Checklist](library/testing/TEST_CASES_AND_QA_CHECKLIST.md)**: 40+ comprehensive test cases for functional, security, offline resilience, and edge case testing.
- 🧭 **[Library Master Index & Update Runbook](library/README.md)**: Developer runbook for updating songs, UI, or backend connectivity.

---

## 🚀 Key Features

### 1. 🇮🇳 100% Free Authentic Indian Master Library (17 Tracks)
- All tracks bundled directly in the application asset package for guaranteed offline listening without internet data:
  - **Bhakti & Mantras:** *Hanuman Chalisa (Sai Charan), Sankat Mochan Hanuman Ashtak (Hariharan), Ye Chamak Ye Damak, Ram Siya Ram, Radhe Tere Charno Ki Dhool.*
  - **Sufi & Punjabi:** *Guzarish, Udaarian, Sajjan Raazi, Tere Bina Na Guzara, Satinder Sartaaj Jukebox.*
  - **Bollywood & Indie:** *Jaiye Sajana, Intezaar Reh Gya.*
  - **Aghori & Spiritual:** *Alakh Niranjan Aghori Trance, Aadesh Hanuman, Siddh Shabar Mantra.*
  - **Lo-Fi & Ghazal:** *Bajrang Baan Lo-Fi (11 Baar Non-Stop), Kagaz Ki Kashti (Jagjit Singh).*

### 2. 🔐 Mandatory 2-Factor User Registration
- Built-in onboarding wizard requiring **Full Name**, **Mobile Phone SMS OTP (6 digits)**, and **Email Verification Code (4 digits)**.
- Unverified users are gated by the `AuthScreen` barrier.
- User profile, verification timestamps, and active status persist locally via `SharedPreferences`.

### 3. 🔍 Real-Time Duplicate Song Detection
- Community upload form checks submitted track titles and artists in real-time against all curated and existing songs.
- If duplicate is found: displays an immediate alert dialog and provides a one-tap `[Play Song Now]` button that jumps directly into playback.
- If unique: submits to Admin review queue (`status: 'pending'`).

### 4. 📤 Direct Native APK File Sharing (No Links)
- Tap the `Share APK` card to share the actual `.apk` file directly via Android's native sharesheet (`application/vnd.android.package-archive`).
- Powered by `com.Musixa.player/app_share` MethodChannel and `androidx.core.content.FileProvider`.
- Shares the real installer file directly to WhatsApp, Bluetooth, Nearby Share, or Telegram without any web links or text invites.

### 5. 🛡️ Executive Admin Dashboard & CRM
- Protected by Master PIN: **`7777`**.
- Executive metrics: *Total Registered Users, Currently Active/Online Users, Pending Songs, Live Songs*.
- **Moderation Center:** Listen to audio previews inside the app before choosing `[Approve]` or `[Reject]`.
- **User Directory:** Searchable directory with live online dots and instant action buttons:
  - `[📞 Call]`: Opens native dialer.
  - `[💬 WhatsApp]`: Starts WhatsApp chat with user.
  - `[✉️ Email]`: Launches email client.

---

## 📁 Repository Directory Structure

```
Musixa_player/
├── .github/workflows/
│   └── build_apk.yml                 # Dual-APK CI/CD automated build workflow
├── android/
│   ├── app/
│   │   ├── build.gradle              # Gradle dependencies & Kotlin stdlib version locks
│   │   └── src/main/
│   │       ├── AndroidManifest.xml   # FileProvider, MediaBrowserService & permissions
│   │       ├── kotlin/.../MainActivity.kt  # MethodChannel for APK file sharing
│   │       └── res/xml/file_paths.xml      # FileProvider cache paths
│   ├── build.gradle                  # Root Gradle build script
│   └── settings.gradle               # Plugin management & Kotlin 1.9/1.8 resolution
├── assets/
│   ├── audio/                        # 17 Bundled Indian master MP3 recordings
│   └── images/                       # App icons & branding
├── library/                          # 📚 Comprehensive Platform Library & Docs
│   ├── README.md                     # Library index & developer runbook
│   ├── brd/
│   │   └── BRD_DOCUMENT_Musixa_PLATFORM.md
│   ├── technical/
│   │   └── TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md
│   └── testing/
│       └── TEST_CASES_AND_QA_CHECKLIST.md
├── lib/
│   ├── main.dart                     # User App entry point
│   ├── main_admin.dart               # Admin App entry point (PIN 7777)
│   ├── models/                       # Song, UserProfile, Playlist, EqualizerPreset
│   ├── services/
│   │   ├── cloud_backend_service.dart # Central singleton for Auth, OTP & Moderation
│   │   ├── audio_player_service.dart  # Low-level just_audio & audio_service engine
│   │   ├── catalog_service.dart       # 17 Indian master tracks catalog
│   │   ├── app_share_service.dart     # Native MethodChannel APK sharing
│   │   ├── device_audio_service.dart  # Offline storage scanner
│   │   └── storage_service.dart       # Local persistence
│   ├── providers/
│   │   └── player_provider.dart       # Audio playback state controller
│   ├── screens/
│   │   ├── auth/auth_screen.dart      # 3-step registration & OTP wizard
│   │   ├── admin/admin_dashboard_screen.dart # Admin KPI, moderation & directory
│   │   ├── home_screen.dart           # Home screen with community songs shelf
│   │   ├── upload_song_screen.dart    # Song upload with duplicate check
│   │   ├── now_playing_screen.dart    # Full-screen vinyl turntable player
│   │   └── equalizer_screen.dart      # 5-band studio graphic equalizer
│   └── theme/
│       ├── app_colors.dart            # Obsidian dark theme & neon glow palette
│       └── app_theme.dart             # Typography & Material 3 config
└── pubspec.yaml                      # Project dependencies & asset declarations
```

---

## 🛠️ Building & Releasing

Release builds are automatically compiled via GitHub Actions:
```bash
# User App (Release APK)
flutter build apk --release --no-tree-shake-icons

# Admin App (Release APK)
flutter build apk --release --target=lib/main_admin.dart --no-tree-shake-icons
```
Artifacts are automatically published to GitHub Actions and downloaded to your local `Downloads` directory.
