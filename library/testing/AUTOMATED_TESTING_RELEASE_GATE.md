# 🛡️ Msixa Mandatory Automated Testing & Release Quality Gate Protocol

**Effective Date:** Continuous / Permanent  
**Enforced For:** Every implementation, bug fix, feature request, and release build.

---

## 🎯 Protocol Mandate (Strict Quality Assurance)

As per explicit project governance:
> **"Jab bhi koi implement ya command aaye, uska ek proper automated testing har bar karni hai aur koi bug ho to usko fix karne ke baad hi release dena hai aage ke liye har baar."**

No release APK shall ever be delivered or published without passing 100% of all automated unit, integration, and regression test suites.

---

## 🔄 Five-Step Quality Lifecycle (Every Task)

```
[1. User Command / Feature Implementation]
                   │
                   ▼
[2. Automated Test Suite Authoring / Extension]
  - Add unit/integration tests to `test/msixa_features_test.dart`
  - Cover edge cases, error conditions, and regressions
                   │
                   ▼
[3. Automated Test Execution (`flutter test`)]
  - Run the test suite
                   │
         ┌─────────┴─────────┐
      [Fail]               [Pass]
         │                   │
         ▼                   │
[4. Bug Isolation & Fix]     │
  - Fix issues in code       │
  - Re-run tests until 100%  │
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
[5. Release Build & Distribution]
  - CI/CD verifies tests in clean runner
  - Dual APKs generated and distributed only after 100% green tests
```

---

## 🧪 Core Test Coverage Areas

1. **Song Data & Serialization:**
   - JSON encoding/decoding with backward compatibility.
   - Category and SubCategory hierarchy mapping.
2. **Folder Hierarchy Detection:**
   - Root folder as Category, subfolders as SubCategory.
   - Ignoring Android/iOS root storage paths (`/storage/emulated/0`, etc.).
3. **Duplicate Prevention:**
   - Exact and normalized song name duplicate checking during bulk and single uploads.
4. **Instant Cloud Sync & Deletion:**
   - Instant tombstoning of deleted songs.
   - Periodic 3-second sync verification and immediate playback stop.
5. **Access Control & Permissions:**
   - Regular user restrictions (single song upload only).
   - Admin bulk upload and direct category upload shortcuts.
6. **Background Uploading & WakeLock:**
   - WakeLock retention during device sleep/screen off.
   - Post-completion native notifications.

---

## 🚫 Hard Release Gate Rule
Under NO circumstances will an APK be generated or delivered to the user if any test in the test suite fails. Every bug must be resolved first.

