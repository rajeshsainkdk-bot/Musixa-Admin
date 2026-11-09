# 🧪 QUALITY ASSURANCE (QA) TEST PLAN & EXHAUSTIVE TEST SUITE
## System: Musixa Player & Musixa Admin Platform
**Target Releases:** `Musixa-Player-APK` (User) & `Musixa-Admin-APK` (Admin)  
**Test Documentation Standard:** IEEE 829 Software Test Documentation  
**Version:** 2.0  
**Archive Location:** `library/testing/TEST_CASES_AND_QA_CHECKLIST.md`  

---

## 1. Test Strategy & Scope Matrix

| Test Suite ID | Focus Area | Testing Type | Test Cases Count | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **TS-01** | User Onboarding & 2-Step OTP Authentication | Functional / Security | 8 Cases | Critical |
| **TS-02** | Master Indian Audio Playback & Offline Resilience | Functional / Performance | 8 Cases | Critical |
| **TS-03** | Community Upload & Real-Time Duplicate Engine | Functional / Negative | 7 Cases | High |
| **TS-04** | Native Direct APK File Sharing (FileProvider) | Integration / Device OS | 5 Cases | Critical |
| **TS-05** | Admin Portal, Moderation & User Directory CRM | Functional / Security | 8 Cases | Critical |
| **TS-06** | Equalizer, Sound Presets, Sleep Timer & FX | UI / Audio DSP | 6 Cases | Medium |
| **TS-07** | Network Interruption, Audio Focus & Edge Scenarios | Reliability / Stress | 6 Cases | High |

---

## 2. Test Suite 1: User Onboarding & Authentication (TS-01)

### TC-AUTH-001: First-Time User Auth Screen Launch
- **Precondition:** Fresh installation of `Musixa-Player-APK`, app data cleared.
- **Test Steps:**
  1. Launch Musixa Player.
  2. Observe the initial screen displayed.
- **Expected Result:** `AuthScreen` is rendered immediately with `[Login]` and `[Register]` tabs. The main player is completely inaccessible until authentication.
- **Status:** PASS

### TC-AUTH-002: Direct Login Attempt with Unregistered Mobile Number
- **Precondition:** On `AuthScreen` Login tab. Mobile number `9123456780` is NOT in the user directory.
- **Test Steps:**
  1. Enter mobile number `9123456780` and any password.
  2. Tap `[🔑 लॉगिन करें व संगीत सुनें (Login)]`.
- **Expected Result:** Login is blocked. Clear notification appears: *"⚠️ यह मोबाइल नंबर रजिस्टर्ड नहीं है! कृपया पहले नया रजिस्ट्रेशन करें।"* A 1-tap `[👉 अभी नया खाता बनाएं (Register)]` button is shown and pre-fills the number on Register tab.
- **Status:** PASS

### TC-AUTH-003: Duplicate Registration Attempt with Existing Mobile Number
- **Precondition:** User `9876543210` already exists in `_allUsers`.
- **Test Steps:**
  1. Switch to `Register` tab.
  2. Enter Full Name, already registered phone `9876543210`, email, and password.
  3. Tap `[✨ खाता बनाएं व शुरू करें (Register)]`.
- **Expected Result:** Registration is halted. Notification appears: *"ℹ️ यह नंबर पहले से रजिस्टर्ड है! कृपया सीधे पासवर्ड डालकर लॉगिन करें।"* UI automatically toggles to `Login` tab with `9876543210` pre-filled.
- **Status:** PASS

### TC-AUTH-004: First-Time Registration with Name, Mobile, Email & Password
- **Precondition:** Unique inputs: Name: `Rajesh Sain`, Phone: `9876500001`, Email: `rajesh@example.com`, Password: `mySecretPass123`.
- **Test Steps:**
  1. Fill all 4 mandatory fields on Register tab.
  2. Tap `[✨ खाता बनाएं व शुरू करें]`.
- **Expected Result:** Account is instantly created. User profile is saved to persistent directory with User ID `+91 9876500001`. Toast *"स्वागत है! आपका Musixa खाता सफलतापूर्वक बन गया है।"* appears. User enters `MainNavigationScreen`.
- **Status:** PASS

### TC-AUTH-005: Incorrect Password Entry during Login (Negative Test)
- **Precondition:** Registered user `9876500001` exists with password `mySecretPass123`.
- **Test Steps:**
  1. On Login tab, enter `9876500001` and wrong password `wrongPass999`.
  2. Tap `[🔑 लॉगिन करें]`.
- **Expected Result:** Authentication fails. Warning displays: *"❌ गलत पासवर्ड! कृपया सही पासवर्ड दर्ज करें।"* Session is not created.
- **Status:** PASS

### TC-AUTH-006: Successful Login & Instant Playlist/Favorites Recovery
- **Precondition:** User `9876500001` created playlists and liked tracks in an earlier session.
- **Test Steps:**
  1. On Login tab, enter `9876500001` and correct password `mySecretPass123`.
  2. Tap `[🔑 लॉगिन करें]`.
- **Expected Result:** Login succeeds immediately. Toast *"वापसी पर स्वागत है! आपकी प्लेलिस्ट व गाने लोड हो गए हैं।"* appears. In Library tab, all previous custom playlists, favorites, and history are fully restored and playable.
- **Status:** PASS

### TC-AUTH-006: Language Switcher Toggle on Auth Screen
- **Precondition:** On `AuthScreen`.
- **Test Steps:**
  1. Tap the top-right language toggle button `[ 🇮🇳 हिंदी / English ]`.
- **Expected Result:** All labels, placeholders, stepper titles, and buttons instantly switch language between Hindi and English without reloading or losing input data.
- **Status:** PASS

### TC-AUTH-007: Cross-App Real-Time User Sync to Admin Dashboard
- **Precondition:** User registers on User App (`Musixa Player`) on the device.
- **Test Steps:**
  1. Complete registration for a new user (e.g. `Kavita Sharma`, `9876543222`).
  2. Switch to / launch `Musixa Player Admin` app.
  3. Navigate to "यूज़र्स डेटा (Users Directory)" tab or tap `[🔄 Refresh Data]` in AppBar.
- **Expected Result:** Newly registered user `Kavita Sharma` with phone `+91 9876543222` appears immediately in the Admin directory with real-time `Active (Online)` indicator and working Call/WhatsApp/Email action buttons.
- **Status:** PASS

### TC-AUTH-008: User Profile Screen & Identity Verification
- **Precondition:** Logged-in user on User App home screen.
- **Test Steps:**
  1. Tap the Profile icon in top header or Library tab.
  2. Verify displayed details: Full Name, User ID / Phone (+91), Email, Status, Registration Date.
  3. Tap `[लॉग आउट करें (Sign Out)]` and confirm dialog.
- **Expected Result:** Profile screen displays all authenticated details accurately. Tapping Sign Out clears session and returns to AuthScreen.
- **Status:** PASS

---

## 3. Test Suite 2: Audio Playback & Offline Resilience (TS-02)

### TC-PLAY-001: Instant Playback of Bundled Indian Master Tracks
- **Precondition:** User on Home screen.
- **Test Steps:**
  1. Tap on "Sankat Mochan Hanuman Ashtak" by Hariharan.
- **Expected Result:** Audio starts instantly (< 200ms latency). Vinyl disc starts rotating. Mini-player appears docked at bottom.
- **Status:** PASS

### TC-PLAY-002: 100% Airplane Mode / Offline Playback
- **Precondition:** Turn ON Airplane mode on Android device (disconnect WiFi and Mobile Data).
- **Test Steps:**
  1. Select any track from Bhakti, Sufi, Bollywood, or Aghori playlists.
  2. Observe playback behavior.
- **Expected Result:** All 17 bundled tracks play flawlessly without errors, loading spinners, or interruptions.
- **Status:** PASS

### TC-PLAY-003: Now Playing Full-Screen View & Turntable Physics
- **Precondition:** Song currently playing.
- **Test Steps:**
  1. Tap on the floating mini-player.
  2. Observe the full-screen player animations.
- **Expected Result:** Vinyl disc spins smoothly with ambient backlight aura matching album palette. Equalizer bars animate dynamically with song rhythm.
- **Status:** PASS

### TC-PLAY-004: Playback Controls (Play, Pause, Next, Previous)
- **Precondition:** Full-screen player active with playlist queue.
- **Test Steps:**
  1. Tap Pause $\rightarrow$ Audio halts, turntable stops.
  2. Tap Play $\rightarrow$ Audio resumes, turntable resumes spinning.
  3. Tap Next $\rightarrow$ Seamlessly transitions to next track in queue.
  4. Tap Previous $\rightarrow$ Returns to previous track or restarts track if position > 3s.
- **Expected Result:** All controls behave responsively without audio stutter.
- **Status:** PASS

### TC-PLAY-005: Playback Modes (Shuffle, Repeat All, Repeat One)
- **Precondition:** Full-screen player active.
- **Test Steps:**
  1. Toggle Repeat to "Repeat One" $\rightarrow$ Track loops continuously when reaching completion.
  2. Toggle Repeat to "Repeat All" $\rightarrow$ Loops queue.
  3. Toggle Shuffle ON $\rightarrow$ Queue order is randomized without repeating played tracks.
- **Expected Result:** Queue logic functions strictly per state flags.
- **Status:** PASS

### TC-PLAY-006: Seeking & Scrubbing
- **Precondition:** Song playing at 0:30.
- **Test Steps:**
  1. Drag progress slider to 2:15.
  2. Release thumb.
- **Expected Result:** Audio immediately seeks to 2:15 without desync between slider and audio position.
- **Status:** PASS

### TC-PLAY-007: Background Playback & Lock Screen Controls
- **Precondition:** Audio playing.
- **Test Steps:**
  1. Press device Power button to lock screen.
  2. Observe lock screen.
  3. Tap Next button on lock screen media widget.
- **Expected Result:** Audio continues playing seamlessly. Lock screen notification displays track art, title, artist, and responds to Play/Pause/Next buttons.
- **Status:** PASS

### TC-PLAY-008: Audio Focus Interruption (Incoming Phone Call)
- **Precondition:** Audio playing on headphones.
- **Test Steps:**
  1. Trigger an incoming cellular call to test device.
  2. End call.
- **Expected Result:** Audio automatically ducks/pauses during the call, and cleanly resumes once the call terminates.
- **Status:** PASS

---

## 4. Test Suite 3: Community Upload & Real-Time Duplicate Engine (TS-03)

### TC-UPLD-001: Access Community Upload Form
- **Precondition:** Logged-in user on Home screen.
- **Test Steps:**
  1. Look at top heading bar.
  2. Verify only `+ Upload Song` is present (no duplicate share button).
  3. Tap `+ Upload Song`.
- **Expected Result:** `UploadSongScreen` opens with audio file picker, title, artist, album, genre, and cover URL fields.
- **Status:** PASS

### TC-UPLD-002: Real-Time Duplicate Detection on Exact Title
- **Precondition:** On `UploadSongScreen`.
- **Test Steps:**
  1. Type Title: `Sankat Mochan Hanuman Ashtak`.
  2. Type Artist: `Hariharan`.
  3. Tap `[Upload Song]`.
- **Expected Result:** System triggers instant duplicate alert: `[⚠️ गाना पहले से मौजूद है]`. Message explains the track is already available.
- **Status:** PASS

### TC-UPLD-003: Duplicate Dialog Direct Play Trigger
- **Precondition:** Duplicate dialog displayed from TC-UPLD-002.
- **Test Steps:**
  1. Tap `[गाना अभी सुनें (Play Now)]`.
- **Expected Result:** Upload screen closes, player immediately begins playing the existing master track `Sankat Mochan Hanuman Ashtak`.
- **Status:** PASS

### TC-UPLD-004: Fuzzy Match Duplicate Detection (Case-Insensitive & Partial)
- **Precondition:** On `UploadSongScreen`.
- **Test Steps:**
  1. Type Title: `sankat mochan hanuman`.
  2. Type Artist: `hariharan`.
- **Expected Result:** Fuzzy matching algorithm catches the substring match (> 4 chars) and flags duplicate.
- **Status:** PASS

### TC-UPLD-005: Successful Unique Song Submission
- **Precondition:** On `UploadSongScreen`.
- **Test Steps:**
  1. Select a local audio file (`my_new_song.mp3`).
  2. Type Title: `Subah Ki Aarti 2026`.
  3. Type Artist: `Pandit Ramesh`.
  4. Select Genre: `Bhakti`.
  5. Tap `[Upload Song]`.
- **Expected Result:** Upload succeeds with confirmation snackbar: `[गाने की समीक्षा की जाएगी (Pending Approval)]`. Track enters `status: 'pending'`.
- **Status:** PASS

### TC-UPLD-006: Pending Song Isolation (Not Live for Other Users)
- **Precondition:** Unique song submitted in TC-UPLD-005.
- **Test Steps:**
  1. Return to User App Home Screen.
  2. Check `"🔥 Newly Added by Community"` shelf.
- **Expected Result:** The newly uploaded song is NOT visible in the public community shelf. It remains hidden until Admin approves.
- **Status:** PASS

---

## 5. Test Suite 4: Direct Native APK File Sharing (TS-04)

### TC-SHAR-001: Verification of Top Heading Row
- **Precondition:** User App Home Screen.
- **Test Steps:**
  1. Inspect the top heading row next to "Musixa Player".
- **Expected Result:** Only `+ Upload Song` is present. No share icon/button in the top header.
- **Status:** PASS

### TC-SHAR-002: Direct APK Sharing Trigger
- **Precondition:** User App Home Screen.
- **Test Steps:**
  1. Locate the middle card: "Share App APK with Friends".
  2. Tap `[Share APK]`.
- **Expected Result:** Native Android sharesheet opens. Sharesheet payload indicates `MusixaPlayer.apk` (`application/vnd.android.package-archive`).
- **Status:** PASS

### TC-SHAR-003: Zero Web Links / Zero Plain Text Sharing
- **Precondition:** Tap `[Share APK]` and select WhatsApp or Telegram.
- **Test Steps:**
  1. Select a recipient on WhatsApp.
  2. Observe the compose input box.
- **Expected Result:** The actual installer file `MusixaPlayer.apk` is attached as a document. There are NO text links, NO URLs, and NO web invites.
- **Status:** PASS

### TC-SHAR-004: File Transfer & Installation on Recipient Device
- **Precondition:** APK file sent via WhatsApp / Nearby Share.
- **Test Steps:**
  1. On receiving phone, tap the received `MusixaPlayer.apk`.
  2. Tap "Install".
- **Expected Result:** Package installer opens, verifies package `com.Musixa.Musixa_player`, and completes installation successfully.
- **Status:** PASS

### TC-SHAR-005: Fallback Mechanism if Local APK File Exists in Downloads
- **Precondition:** Device where `base.apk` extraction is mocked or restricted.
- **Test Steps:**
  1. Ensure a file named `MusixaPlayer.apk` exists in `/storage/emulated/0/Download/`.
  2. Trigger `AppShareService.shareAppApk()`.
- **Expected Result:** Fallback catches local file and shares it via `Share.shareXFiles` without crashing.
- **Status:** PASS

---

## 6. Test Suite 5: Admin Dashboard, Moderation & CRM Directory (TS-05)

### TC-ADMN-001: Admin Master PIN Authentication
- **Precondition:** Open `Musixa-Admin-APK`.
- **Test Steps:**
  1. Enter incorrect PIN `1234` $\rightarrow$ Access denied, error vibration.
  2. Enter correct PIN `7777`.
- **Expected Result:** Admin dashboard loads with executive KPI cards and Tab bar.
- **Status:** PASS

### TC-ADMN-002: Live Executive Analytics Cards
- **Precondition:** Admin Dashboard loaded.
- **Test Steps:**
  1. Check metric cards:
     - "कुल यूज़र्स (Total Users)"
     - "सक्रिय (Active Users)"
     - "लंबित अप्रूवल (Pending Approvals)"
     - "लाइव गाने (Live Songs)"
- **Expected Result:** Numbers accurately reflect backend state and update dynamically.
- **Status:** PASS

### TC-ADMN-003: In-App Audio Preview for Moderation
- **Precondition:** Admin on Tab 1 ("लंबित गाने").
- **Test Steps:**
  1. Find pending track uploaded in TC-UPLD-005.
  2. Tap `[सुनें (Preview)]`.
- **Expected Result:** Audio plays directly inside Admin App. Button toggles to `[रुकें (Playing)]` in amber theme.
- **Status:** PASS

### TC-ADMN-004: Song Approval Workflow
- **Precondition:** Pending track selected.
- **Test Steps:**
  1. Tap `[स्वीकार करें (Approve)]`.
  2. Observe Tab 1 and Tab 3.
- **Expected Result:** Song disappears from "लंबित गाने" and moves to "लाइव गाने". In User App, the song immediately appears on `"🔥 Newly Added by Community"`.
- **Status:** PASS

### TC-ADMN-005: Song Rejection / Removal Workflow
- **Precondition:** Pending track or Live track.
- **Test Steps:**
  1. Tap `[हटाएँ (Reject)]` or Delete icon.
  2. Confirm dialog `[हाँ, हटाएँ]`.
- **Expected Result:** Track is permanently purged from storage. It disappears from both Admin and User applications.
- **Status:** PASS

### TC-ADMN-006: User Directory Search & Active Status
- **Precondition:** Admin on Tab 2 ("यूज़र्स डेटा").
- **Test Steps:**
  1. Type user name or phone number in search box.
- **Expected Result:** List filters in real-time. Active users show green dot indicator; inactive show grey.
- **Status:** PASS

### TC-ADMN-007: One-Tap CRM Call Action
- **Precondition:** User list displayed.
- **Test Steps:**
  1. Tap phone icon next to user.
- **Expected Result:** Native phone dialer opens with user's number pre-dialed (`tel:+91...`).
- **Status:** PASS

### TC-ADMN-008: One-Tap CRM WhatsApp Action
- **Precondition:** User list displayed.
- **Test Steps:**
  1. Tap WhatsApp icon next to user.
- **Expected Result:** WhatsApp opens with pre-filled message addressing the user from Musixa Support.
- **Status:** PASS

---

## 7. Pass/Fail Sign-off Criteria
- **Blocker / Critical Severity Defects:** 0 Allowed.
- **Major Severity Defects:** 0 Allowed.
- **Pass Rate:** $\ge 98\%$ of all test scenarios must achieve clean PASS results before production distribution.

