# 📚 Musixa PLATFORM ENGINEERING & ARCHITECTURE LIBRARY
**Master Repository:** `https://github.com/rajeshsainkdk-bot/Musixa_player.git` (Branch: `main`)  
**Local Codebase:** `C:\Users\rajes\OneDrive\Documents\GitHub\Musixa_player`  
**Current Release Version:** v2.0 (Dual-APK Production Release)  
**Maintenance Owner:** Antigravity AI & Musixa Engineering  

---

## 🧭 Library Contents & Document Navigation

This library contains the complete technical, operational, and business documentation for the Musixa streaming platform. Use the links below to access detailed specifications:

| Document | File Path | Purpose & Description |
| :--- | :--- | :--- |
| **Business Requirements Document (BRD)** | [`BRD_DOCUMENT_Musixa_PLATFORM.md`](brd/BRD_DOCUMENT_Musixa_PLATFORM.md) | High-level vision, user personas, dual-APK architecture, functional requirements (FR-01 to FR-15), NFRs, and product roadmap. |
| **Technical & Theoretical Spec** | [`TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md`](technical/TECHNICAL_ARCHITECTURE_THEORETICAL_SPEC.md) | Deep engineering architecture: Flutter widgets, `CloudBackendService`, duplicate matching math, `FileProvider` native channel, and CI/CD config. |
| **QA Test Suite & Manual Checklist** | [`TEST_CASES_AND_QA_CHECKLIST.md`](testing/TEST_CASES_AND_QA_CHECKLIST.md) | 40+ comprehensive QA test cases covering Onboarding, Offline Audio, Duplicate Detection, Direct APK Sharing, and Admin CRM actions. |

---

## 📦 Deliverables & Production APK Artifacts

Every continuous integration build generates two standalone APK packages stored directly on the machine:

```
C:\Users\rajes\Downloads\
├── Musixa-Player-APK\
│   └── Musixa-player-release.apk     # Public User APK (168 MB, 17 bundled Indian tracks)
└── Musixa-Admin-APK\
    └── Musixa-admin-release.apk      # Executive Admin APK (167 MB, PIN 7777 protected)
```

---

## 🔧 Future Development & Update Runbook

When you want to make future updates or add new features to Musixa, follow this standard procedure:

### 1. Codebase Directory
Always make edits in the root repository directory:
```
C:\Users\rajes\OneDrive\Documents\GitHub\Musixa_player
```

### 2. Key Files to Modify for Future Features
- **To add new songs to the bundled catalog:** Edit `lib/services/catalog_service.dart` and add corresponding audio files in `assets/audio/`.
- **To update the User UI or theme:** Edit `lib/screens/home_screen.dart` and `lib/theme/app_colors.dart`.
- **To modify Admin controls (Add / Edit / Remove):** Edit `lib/screens/admin/admin_dashboard_screen.dart` and `lib/services/cloud_backend_service.dart`.
- **To connect a real cloud backend (Cloudflare R2 / Supabase):** Replace mock network methods in `lib/services/cloud_backend_service.dart` with HTTP REST / S3 SDK calls.

### 3. Automated Push, Build & Download Pipeline
To push changes and automatically build new APKs without interruptions:
Run the automated monitoring script located at:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\rajes\.gemini\antigravity\brain\29cecb86-2313-4d4a-8d85-442899486999\scratch\push_and_monitor.ps1"
```
This script automatically:
1. Adds and commits all modified files to Git.
2. Pushes directly to GitHub `main` branch.
3. Hooks into GitHub Actions runner (`build_apk.yml`).
4. Compiles both release APKs.
5. Downloads and unzips both fresh APKs straight into `C:\Users\rajes\Downloads\`.

---

## 🛡️ Security & Access Control Reference
- **Admin App Master PIN:** `7777`
- **Native MethodChannel:** `com.Musixa.player/app_share`
- **Native FileProvider Authority:** `com.Musixa.Musixa_player.fileprovider`
- **GitHub Token ID:** Configured in `push_and_monitor.ps1` with workflow and repo write permissions.

