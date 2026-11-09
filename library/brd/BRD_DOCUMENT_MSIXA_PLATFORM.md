# 📄 BUSINESS REQUIREMENTS DOCUMENT (BRD)
## Project Name: Musixa Music Streaming & Community Ecosystem
**System Architecture:** Dual-APK Platform (Musixa Player & Musixa Admin)  
**Version:** 2.0 (Production Release)  
**Document Owner:** Antigravity AI Engineering Team  
**Status:** Approved & Archive Reference  
**Last Updated:** November 2026  

---

## 1. Executive Summary & Vision Statement

### 1.1 Vision
Musixa is an ad-free, 100% free Indian music streaming and community-driven audio distribution ecosystem. It solves the fragmentation and aggressive paywalls of modern commercial music apps by providing:
1. **Instant, Zero-Cost High-Fidelity Audio**: 17 curated, master-quality Indian tracks bundled locally for guaranteed offline and online playback without subscriptions.
2. **Verified Community Uploads**: Any registered listener can contribute independent tracks, safeguarded by real-time duplicate detection algorithms.
3. **Rigorous Administrative Moderation**: Zero unverified content reaches users. A separate, dedicated Admin application enforces platform standards, audio quality checks, and real-time user directory visibility.
4. **Viral Offline Distribution**: Native, link-free APK file sharing enables viral peer-to-peer distribution across rural and low-bandwidth environments via WhatsApp, Bluetooth, and Nearby Share.

---

## 2. Business Objectives & Success Metrics (KPIs)

| Objective | Target Metric | Business Value |
| :--- | :--- | :--- |
| **Zero Paywall Barrier** | 100% free access to all bundled audio | Maximizes listener retention and app adoption. |
| **Clean User Identity** | 100% verified phone & email accounts | Eliminates bot accounts, spam uploads, and malicious content. |
| **Audio Quality Control** | 0% unmoderated uploads live on platform | Admin approval gate ensures only high-fidelity music is published. |
| **Duplicate Prevention** | < 1s instant duplicate matching & redirect | Saves cloud storage bandwidth and prevents catalog clutter. |
| **Viral Direct Sharing** | 1-tap APK installation transfer | Enables direct user acquisition without requiring Google Play Store access. |

---

## 3. Dual-Application Ecosystem Architecture

The platform is partitioned into two distinct native Android applications built from a single unified Flutter codebase:

```mermaid
graph TD
    subgraph "Public Distribution Channel"
        UAPK["Musixa Player (User APK)<br/><code>com.Musixa.Musixa_player</code>"]
    end

    subgraph "Internal Operations Channel"
        AAPK["Musixa Admin (Admin APK)<br/><code>com.Musixa.admin</code>"]
    end

    subgraph "Shared Cloud & Local Backend"
        CBS["CloudBackendService (Singleton)"]
        SP["Encrypted Shared Storage (SharedPreferences)"]
        FS["FileProvider Native Extraction (MusixaPlayer.apk)"]
    end

    UAPK -->|User Registration & Auth| CBS
    UAPK -->|Song Upload with Dup Check| CBS
    UAPK -->|Share APK File| FS
    AAPK -->|PIN 7777 Auth| CBS
    AAPK -->|Audio Preview & Approve/Reject| CBS
    AAPK -->|User Directory CRM (Call/WA/Email)| CBS
    CBS <--> SP
```

---

## 4. User Personas

### 4.1 Persona 1: The Devotional & Melodic Listener (Aman, 28)
- **Goal:** Wants to listen to Hanuman Chalisa, Satinder Sartaaj Sufi songs, and Ghazals without paying monthly subscriptions or listening to annoying ads.
- **Pain Point:** Most streaming apps lock high-quality audio behind premium plans and delete songs when offline.
- **Musixa Solution:** Instant offline playback of 17 bundled master tracks with 5-band studio equalizer and sleep timer.

### 4.2 Persona 2: The Indie Musician / Contributor (Pooja, 22)
- **Goal:** Wants to share her original devotional covers and indie music with a growing Indian music community.
- **Pain Point:** Getting music on major streaming platforms requires distributor fees and weeks of review.
- **Musixa Solution:** Simple in-app upload screen. Instant duplicate check prevents accidental reposts. Tracks enter Admin review queue and go live platform-wide upon approval.

### 4.3 Persona 3: Platform Super Administrator (Admin Rajesh)
- **Goal:** Full visibility into platform operations: who is listening, how many active users, which songs are pending review, and direct communication channels.
- **Musixa Solution:** Dedicated Admin APK protected by Master PIN (`7777`), executive KPI cards, in-app audio preview player, and one-tap Call/WhatsApp/Email triggers for every registered user.

---

## 5. Detailed Functional Requirements (FR)

### FR-01: Bundled Curated Indian Master Library
- **Description:** The system must bundle 17 high-fidelity master recordings directly within the asset bundle across 5 distinct cultural categories:
  1. *Bhakti & Devotional:* Hanuman Chalisa (Sai Charan), Sankat Mochan Hanuman Ashtak (Hariharan), Ye Chamak Ye Damak (Sudhir Vyas), Ram Siya Ram, Radhe Tere Charno Ki Dhool.
  2. *Sufi & Punjabi:* Guzarish, Udaarian, Sajjan Raazi, Tere Bina Na Guzara, Satinder Sartaaj Jukebox.
  3. *Bollywood & Indie:* Jaiye Sajana, Intezaar Reh Gya.
  4. *Spiritual & Aghori:* Alakh Niranjan, Aadesh Hanuman, Siddh Shabar Mantra.
  5. *Lo-Fi & Ghazal:* Bajrang Baan Lo-Fi (11 Baar Non-Stop), Kagaz Ki Kashti (Jagjit Singh).
- **Acceptance Criteria:** Songs must play instantly with zero network buffering when the user is offline.

### FR-02: Password-Based Authentication with Mobile Number as User ID (Zero OTP)
- **Description:** User authentication is entirely decoupled from telecom SMS OTPs and replaced with a robust User ID (Mobile Number) + User-Created Password mechanism.
- **User Roles & Flow Paths:**
  1. *New User Registration:*
     - Mandatory inputs: Full Name (min 2 chars), 10-Digit Mobile Number (serves as User ID), Email Address, and Password (min 4 chars).
     - If the mobile number already exists in the registered users directory, registration is blocked with notification: *"यह नंबर पहले से रजिस्टर्ड है! कृपया सीधे पासवर्ड डालकर लॉगिन करें"*, automatically switching the user to Login mode with their phone pre-filled.
  2. *Returning User Login:*
     - Mandatory inputs: 10-Digit Mobile Number (User ID) and Password.
     - If the mobile number is NOT found in the user list, login is rejected with clear guidance: *"यह मोबाइल नंबर रजिस्टर्ड नहीं है! कृपया पहले नया रजिस्ट्रेशन करें"*, preventing unauthorized access and offering an immediate 1-tap transition to Register mode.
     - On successful password verification: Session is established, user heartbeat is recorded, and all previously created playlists, liked songs, and playback history are immediately loaded into the player.
- **Acceptance Criteria:** Direct login is impossible without prior registration. Attempting duplicate registration redirects to login. Returning users recover all personal playlists upon entering their registered number and password.

### FR-03: Real-Time Active User Heartbeat & Analytics
- **Description:** The client sends periodic timestamp heartbeats upon app foregrounding and song playback.
- **Acceptance Criteria:** Users active within the last 60 minutes are marked as `Active (Online)` in the Admin Dashboard with a green indicator.

### FR-04: Community Song Upload Screen
- **Description:** Authenticated users can upload audio files (`.mp3`, `.m4a`, `.wav`) along with Track Title, Artist Name, Album, Genre, and optional Cover Art URL.
- **Acceptance Criteria:** Submissions default to `status: 'pending'` and are inaccessible to general users until Admin approval.

### FR-05: Real-Time Duplicate Song Detection & Instant Redirect
- **Description:** Before creating a submission, the system runs a fuzzy normalization algorithm against all curated tracks and approved community tracks.
- **Acceptance Criteria:**
  - If a match is detected: Upload form halts, displays an alert dialog `[⚠️ गाना पहले से मौजूद है]`, and provides an immediate `[गाना अभी सुनें (Play Now)]` button that starts playback immediately.
  - If unique: Enters the moderation queue.

### FR-06: Enterprise Admin Authentication (Master PIN)
- **Description:** Admin APK entry is restricted by a secure numeric PIN interface (`7777`).
- **Acceptance Criteria:** Incorrect PIN shows error vibration and prevents access; correct PIN grants persistent Super Admin credentials.

### FR-07: In-App Song Moderation Center
- **Description:** Admin dashboard displays all `pending` songs with uploader details (Full Name, Phone number).
- **Actions:**
  - `[सुनें (Preview)]`: Streams audio within the Admin app for quality/copyright audit.
  - `[स्वीकार करें (Approve)]`: Transitions song to `status: 'approved'`. Instantly exposes song on the User App's `"🔥 Newly Added by Community"` shelf.
  - `[हटाएँ (Reject)]`: Permanently purges submission with confirmation.

### FR-08: Searchable Users Directory with Native CRM Triggers & Cross-App Sync
- **Description:** Admin views all registered users with real-time active indicators, email, and phone numbers.
- **Cross-App Sync:** Synchronized between User App (`com.Musixa.Musixa_player`) and Admin App (`com.Musixa.admin`) via shared storage and `android:sharedUserId`.
- **One-Tap Actions:**
  - `[📞 Call]`: Opens device phone dialer with user's number.
  - `[💬 WhatsApp]`: Launches official WhatsApp chat with pre-filled support message.
  - `[✉️ Email]`: Opens default mail client addressing the user.
  - `[🔄 Refresh]`: Instant sync button in AppBar to re-read cross-app database.

### FR-09: Direct Native APK File Sharing (No Links)
- **Description:** In the User App, clicking the `Share APK` card triggers native Android file sharing (`Intent.ACTION_SEND`).
- **Mechanism:** Extracts installed `base.apk` from `applicationInfo.sourceDir` into app cache via `androidx.core.content.FileProvider`.
- **Acceptance Criteria:** Shares the actual `.apk` file (`application/vnd.android.package-archive`). Strictly zero web links or plain text messages are transmitted.

### FR-10: User Profile & Account Settings Hub
- **Description:** Dedicated profile dashboard in User App displaying authenticated identity details:
  - Full Name, User ID (Mobile Number with verified badge), Email Address, Member Since date, Online Status.
  - Quick App Preferences: Language Switcher (`🇮🇳 हिंदी` / `🇬🇧 English`), Device Storage Scanner trigger, and Direct APK Sharing.
  - Account Sign Out (`लॉग आउट करें`) action with confirmation dialog.

### FR-11: Background Audio Service & Lock Screen Controls
- **Description:** Audio playback must continue uninterrupted when the screen is locked or the app is minimized.
- **Acceptance Criteria:** Notification bar shows active track title, artist, album art, play/pause, seek bar, and next/prev controls linked to `com.ryanheise.audioservice`.

---

## 6. Non-Functional Requirements (NFR)

| ID | Requirement Category | Specification |
| :--- | :--- | :--- |
| **NFR-01** | **Performance** | App launch time < 1.2s; audio start latency < 300ms on local assets. |
| **NFR-02** | **Audio Fidelity** | 320 kbps MP3 master playback support with 44.1 kHz sampling rate. |
| **NFR-03** | **Network Resilience** | Graceful degradation: all 17 bundled tracks play with 0% data/WiFi connectivity. |
| **NFR-04** | **Security** | FileProvider strictly confines shared file URI scopes with temporary read grant permissions (`FLAG_GRANT_READ_URI_PERMISSION`). |
| **NFR-05** | **Storage Footprint** | Complete standalone APK size < 170 MB including all 17 master audio files. |
| **NFR-06** | **Compatibility** | Minimum Android SDK 21 (Android 5.0 Lollipop) up to Android 14+ (Target SDK 34). |
| **NFR-07** | **Aesthetics** | Obsidian dark surface (`#090D16`), Cyber Cyan (`#00E5FF`), Neon Amber (`#FFB300`), Google Fonts Syne and Outfit. |

---

## 7. Cloud Migration & Storage Architecture (Next Phase Roadmap)

While Version 2.0 bundles local master tracks and local state synchronization, the architecture is pre-configured for seamless cloud migration:
1. **Audio Storage Backend:** Cloudflare R2 object storage (S3-compatible, zero egress bandwidth costs) for hosting user-submitted audio files beyond device memory.
2. **Database & Auth:** Supabase / PostgreSQL or Firebase Firestore for cloud-wide synchronized real-time user directories and community catalog broadcasts.
3. **SMS Gateway:** Fast2SMS / Twilio SMS API for live commercial telecom OTP delivery.

