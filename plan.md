# Mizaan (ميزان) — Yemen Wallets Aggregator & Expense Tracker
## Implementation Plan for Google Antigravity — numbered Steps

> **How to use this document:** Execute the steps **in order** (Step 0 → Step 12). Each step ends with acceptance criteria ("Done when") — verify them before starting the next step. Follow the Golden Rules strictly. If anything is ambiguous, ask before improvising.

---

## 1. Product Summary

An **Arabic (RTL) Flutter app for Android and iOS** that aggregates a user's Yemeni e-wallet balances (Kash / Muhafazati / Jawali / other) into one place and tracks their spending.

- The user adds each wallet once with its **opening balance**, then the app tracks money automatically:
  - **Manual entry**: the user logs transactions (expense / income) in seconds.
  - **SMS auto-import (CORE FEATURE)**: on Android, the app reads incoming wallet SMS messages, filters them by known sender IDs, extracts amounts/balances with per-wallet templates, and creates transactions automatically (`source: 'sms'`).
  - ⚠️ **Platform limitation (state it in code comments and the demo):** iOS does not allow apps to read SMS — on iOS the SMS UI is hidden and the app works fully with manual entry.
- The app computes balances automatically, shows a unified total, spending reports, rule-based insights, low-balance alerts, and balance reconciliation.
- **Offline-first**: everything works without internet (Hive). When online, data syncs to Firestore.

---

## 2. Golden Rules (DO / DO NOT)

### ✅ DO
- Target **Android and iOS ONLY** — generate the project with `flutter create --platforms android,ios`.
- Write any native Android code in **Kotlin only** (the default `MainActivity.kt`).
- Build the UI fully in **Arabic with RTL support** (`Directionality`, Arabic localization, Arabic user-facing strings).
- Use **offline-first architecture**: every write goes to Hive first, then syncs to Firestore when online.
- Use **flutter_bloc (Cubit)** for all state management.
- Build the **splash animation yourself** with `AnimationController` / `Tween` / `AnimatedBuilder` (course requirement: "animation you build").
- Set Transaction `source` to `'manual'`, `'sms'`, or `'adjustment'` correctly — SMS-imported rows must carry `source: 'sms'`.
- Validate all forms; handle `FirebaseAuthException` codes with friendly Arabic messages.
- Wrap every SMS capability behind a **platform check** (`Platform.isAndroid`) so iOS builds cleanly.
- Test on Android (emulator or device) at the end of every step.
- Follow the **Manual Checkpoints Protocol** below: if a step needs a manual action from the user — **pause, ask the user in Arabic, wait for their confirmation, then verify**. Never fake, mock, or silently skip a requirement.

### ❌ DO NOT
- **DO NOT** create or keep `windows/`, `linux/`, `macos/`, or `web/` folders — **no desktop or web targets at all**.
- **DO NOT** write any **Java** code — native Android code is **Kotlin only**.
- **DO NOT** integrate any AI / LLM API (no Gemini, no OpenAI).
- **DO NOT** use Lottie, Rive, or any ready-made animation package for the splash — it must be hand-built.
- **DO NOT** use Provider / GetX / Riverpod — Cubit only.
- **DO NOT** use sqflite — **Hive** for the local database, **shared_preferences** for settings/flags.
- **DO NOT** attempt any SMS reading on iOS — hide the feature there (Apple forbids it).
- **DO NOT** add features, screens, or packages beyond this plan without asking first.
- **DO NOT** leave English placeholder text in the UI.
- **DO NOT** skip the final acceptance checklist (Section 8).

---

## ⚠️ Manual Checkpoints Protocol (MANDATORY)

Some steps require actions that only the human developer can perform (console accounts, real files, a physical device). At each checkpoint you MUST:

1. **PAUSE** — never start a step whose manual prerequisite is missing.
2. **ASK the user in Arabic** for the exact item/action: what it is, where to get it, and where to place it.
3. **WAIT** for the user's explicit confirmation that it is done.
4. **VERIFY** it (file exists, command succeeds, feature works) before moving to the next step.

If the user cannot provide something, STOP and report it — do not work around course requirements.

### Known manual checkpoints

| Checkpoint | Manual action required from the user |
|---|---|
| **Before Step 1** (Firebase) | Create a Firebase project → enable **Email/Password** auth → create a **Firestore database** → register the Android app (`com.mizaan.app`) → place `google-services.json` in `android/app/` → run `flutterfire configure` (needs the user's Firebase CLI login) so `firebase_options.dart` covers Android + iOS. |
| **Before Step 6** (SMS) | Paste **2–3 real SMS messages from each wallet** (Kash / Muhafazati / Jawali) copied from the user's own phone — regex templates must be built on real text, never guessed. Live-SMS testing needs a real device with a SIM. |
| **Before Step 11** (Icon) | The user provides `assets/icon/app_icon.png` (1024×1024) **or** explicitly approves the generated placeholder. |
| **At Step 12** (APK) | The user installs `mizaan-release.apk` on a real Android device and confirms the smoke test. |

If you discover any other action during the work that only the user can do (accounts, passwords, on-device permissions, files), apply the same protocol: **pause → ask in Arabic → wait → verify**.

---

## 3. Tech Stack (exact — do not substitute)

| Concern | Package / Tool |
|---|---|
| State management | `flutter_bloc` (+ `equatable`) |
| Local database | `hive`, `hive_flutter` (adapters via `hive_generator` + `build_runner`) |
| Settings / flags | `shared_preferences` |
| Backend / Auth | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| Biometrics | `local_auth` |
| Permissions | `permission_handler` |
| Notifications | `flutter_local_notifications` |
| **SMS reading (Android only)** | **`telephony`** |
| Charts | `fl_chart` |
| Formatting | `intl` (Arabic number/date formatting) |
| IDs | `uuid` |
| App icon generation | `flutter_launcher_icons` (dev) |
| Font | Bundle **Cairo** or **Tajawal** TTF as an asset (works offline — no runtime font downloads) |

**Android configuration:**
- `applicationId` → `com.mizaan.app`
- `minSdkVersion 23`, latest `compileSdk`
- `MainActivity` extends **`FlutterFragmentActivity`** (Kotlin — mandatory for `local_auth`)
- Manifest permissions: `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, **`READ_SMS`, `RECEIVE_SMS`**
- `android:label="ميزان"`

**iOS configuration:**
- `NSFaceIDUsageDescription` in `Info.plist` (required by `local_auth`)
- Display name `ميزان` via `flutter_launcher_icons` / `CFBundleDisplayName`
- No SMS permissions — nothing SMS-related on iOS.

---

## 4. Architecture

Feature-first structure with a simple repository pattern:

```
lib/
  main.dart                    // init Firebase, Hive, then runApp
  app.dart                     // MaterialApp: theme, RTL, routes, cubits
  core/
    theme/                     // light/dark ThemeData, colors, text styles
    router/                    // named routes
    constants/                 // wallet types, categories, fee table, SMS sender registry
    utils/                     // formatters, validators, platform helpers
  features/
    splash/                    // screen + animation widgets
    onboarding/                // intro screens
    auth/                      // login, register, biometric gate + AuthCubit
    home/                      // home screen + HomeCubit
    wallets/                   // add wallet, wallet details + WalletsCubit
    transactions/              // add transaction + TransactionsCubit
    sms/                       // SMS import wizard + SmsCubit (Android only)
    favorites/                 // favorites screen
    stats/                     // reports & insights + StatsCubit
    settings/                  // settings + SettingsCubit + ThemeCubit
  data/
    models/                    // Wallet, TransactionModel (Hive adapters)
    repositories/              // WalletRepository, TransactionRepository (Hive + Firestore sync)
    services/                  // SmsService (Android), NotificationService, BiometricService, SyncService
```

**Routing logic:** Splash → (first launch? → Intro) → (logged in? → biometric gate if enabled → Home : Login/Register).

---

## 5. Data Models

### Wallet (Hive, typeId: 0)
```dart
String id            // uuid
String name          // e.g. "كاش"
String type          // kash | muhafazati | jawali | other
int colorValue       // picked color
int iconCodePoint    // picked icon
double openingBalance
bool isFavorite
DateTime createdAt
```

### TransactionModel (Hive, typeId: 1)
```dart
String id            // uuid
String walletId
String type          // expense | income | adjustment
double amount
String category      // أكل | مواصلات | بقالة | فواتير | تحويل | راتب | أخرى
String? note
DateTime date
String source        // manual | sms | adjustment
String? smsKey       // dedupe fingerprint for SMS imports: hash(address + date + body)
DateTime createdAt
```

### Balance logic (pure functions — no AI, no magic)
```
walletBalance = openingBalance + Σ(income) − Σ(expense) ± Σ(adjustment)
totalBalance  = Σ walletBalance across all wallets
```

### Settings (shared_preferences keys)
`themeMode` • `biometricEnabled` • `introSeen` • `lowBalanceThreshold` (default 10000) • `dailyReminderEnabled` (default true) • `smsAutoImportEnabled` (default true, Android)

### Firestore (sync only — Hive is the local source of truth)
```
users/{uid}/wallets/{walletId}
users/{uid}/transactions/{transactionId}
```
Repository pattern: write to Hive → attempt Firestore upsert → mark `synced`. Conflicts resolve last-write-wins. Keep it simple.

---

## 6. Screens & Routes

| Route | Screen | Contents |
|---|---|---|
| `/splash` | Splash | Hand-built animation (Step 2) |
| `/intro` | Introduction | 3 pages via `PageView` + skip; shown once only |
| `/login` | Login | Email/password + fingerprint button (if enabled) |
| `/register` | Register | Name, email, password, confirm password |
| `/home` | Home | Total balance card • wallet cards • today's spending • recent transactions • FAB "➕ حركة" • "مزامنة الرسائل" button (Android) |
| `/add-wallet` | Add Wallet | Name, type, color, icon, **opening balance** |
| `/wallet/:id` | Wallet Details | Balance, transactions, favorite star, "تحديث الرصيد الفعلي" |
| `/add-transaction` | Add Transaction | income/expense toggle, amount, wallet picker, category chips, note, date |
| `/sms-sync` | SMS Import Wizard (Android) | Permission → scan → preview parsed transactions → confirm import |
| `/favorites` | Favorites | Pinned wallets with quick actions |
| `/stats` | Reports | Pie (by category), bar (weekly/monthly), insight cards |
| `/settings` | Settings | Theme, biometric, notifications, SMS senders, threshold, logout |

**Bottom navigation:** الرئيسية • التقارير • المفضلة • الإعدادات

---

## 7. Steps

---

### Step 0 — Project Setup (platforms: Android + iOS only)
1. `flutter create mizaan --org com.mizaan --platforms android,ios` → **no desktop/web folders may exist** (`windows/ linux/ macos/ web/` must NOT be generated).
2. Set `applicationId "com.mizaan.app"`, `minSdkVersion 23`; keep `MainActivity` in **Kotlin** extending `FlutterFragmentActivity`. Never add `.java` files.
3. Add all packages from Section 3 (including `telephony`).
4. Add the bundled Arabic font asset and register it in pubspec.
5. AndroidManifest permissions: `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `READ_SMS`, `RECEIVE_SMS`. iOS: `NSFaceIDUsageDescription`.
6. Create the folder structure from Section 4.

**Done when:** `flutter run` shows a blank Arabic RTL scaffold on Android; `ios/` and `android/` are the only platform folders.

---

### Step 1 — Firebase + Authentication (Login / Register / Biometrics)
1. `flutterfire configure` (Android + iOS apps) and wire `firebase_options.dart`; add `google-services.json` to `.gitignore`.
2. `AuthCubit`: `Unauthenticated / Authenticating / Authenticated / AuthError(arMessage)`.
3. **Register screen**: name, email, password, confirm — full validation + Arabic error messages.
4. **Login screen**: email/password + forgot-password (Firebase reset email).
5. After first successful login → dialog **"تفعيل الدخول بالبصمة؟"** → store `biometricEnabled`.
6. **Biometric gate**: on launch, if a session exists AND biometric is enabled → require `local_auth` before Home. Login screen shows a fingerprint button when enabled.
7. Logout in Settings (biometric flag persists).

**Done when:** register → logout → login → biometric gate all work; wrong password shows an Arabic error; app restart keeps the session behind biometrics.

---

### Step 2 — Splash (hand-built) + Intro + Theme
1. **Splash animation (built by you — NO packages):** 3 coin circles `ScaleTransition` in, slide toward center and merge, a wallet icon pops (`AnimatedScale` with elastic curve), app name "ميزان" fades in. Total ≈ 2 seconds using one `AnimationController`, then route per Section 4 logic.
2. **Intro**: 3 pages (`PageView`) — "محافظك مشتتة؟" → "اجمعها في مكان واحد" → "وراقب كل ريال تلقائياً" — skip + page indicator; set `introSeen=true`.
3. **ThemeCubit**: light/dark/system persisted; both `ThemeData` (primary `#0E7C61`, bundled font).

**Done when:** animation is visibly custom-built and smooth; intro shows once only; theme toggle persists across restarts.

---

### Step 3 — Domain Layer (Hive + Repositories)
1. Generate Hive adapters for both models (`build_runner`).
2. Open `walletsBox`, `transactionsBox`, `smsKeysBox` (dedupe fingerprints) at startup.
3. `WalletRepository` / `TransactionRepository`: CRUD against Hive first, then Firestore sync.
4. Pure balance functions from Section 5.

**Done when:** CRUD works fully offline; balances compute correctly from transactions.

---

### Step 4 — Home + Wallets + Transactions (the core)
1. **Home**: total balance card, horizontal wallet cards, "مصروف اليوم", recent transactions, FAB "➕ حركة", and a **"مزامنة الرسائل 📩"** button (Android only) leading to `/sms-sync`.
2. **Add Wallet**: type selector (كاش/محفظتي/جوالي/أخرى), color + icon picker, opening balance (required).
3. **Add Transaction**: income/expense toggle, amount, wallet dropdown, category chips, note, date. Expense exceeding the wallet balance → warning dialog (allow override).
4. **Wallet Details**: live balance, filtered transactions (SMS-imported ones show a small 📩 badge), favorite star, delete with confirmation.

**Done when:** add wallet (150,000) → income 50,000 → expense 20,000 → wallet shows 180,000; totals update everywhere.

---

### Step 5 — Favorites
1. Star toggle on wallet cards/details.
2. **Favorites screen**: pinned wallets + quick actions (➕ حركة, تفاصيل).

**Done when:** starring in Home instantly reflects in Favorites and persists.

---

### Step 6 — SMS Auto-Import (CORE FEATURE — Android only)
1. **Sender registry** in `core/constants/sms_senders.dart` — an editable map of known wallet sender IDs → wallet type, e.g. `{'Kash': kash, 'MTN': muhafazati, 'YemenMobile': jawali}` (verify against real messages during testing).
2. **Per-wallet parse templates** in the same file — regex for amount and balance, e.g.:
```dart
// Example template — verify against real wallet SMS during testing
WalletSmsTemplate(
  type: kash,
  senderIds: ['Kash'],
  expense: RegExp(r'تم خصم\\s*([\\d,]+)'),
  income:  RegExp(r'تم استلام\\s*([\\d,]+)'),
  balance: RegExp(r'رصيدك الحالي\\s*([\\d,]+)'),
)
```
3. `SmsService` (guarded by `Platform.isAndroid`) using `telephony`:
   - `hasPermission()` / `requestPermission()` — runtime SMS permission.
   - `scanRecent({int count = 100})` → read inbox, **filter by registered senders only**, parse matches, skip unknown senders entirely (never touch personal messages).
   - Dedupe: compute `smsKey = hash(address + date + body)`; skip keys already in `smsKeysBox`.
4. **Import Wizard `/sms-sync`**: permission request with Arabic rationale ("نقرأ رسائل المحافظ فقط لتسجيل حركاتك تلقائياً — رسائلك الشخصية لا تُقرأ أبداً") → scanning indicator → **preview list** (wallet, type, amount, date) with checkboxes → **confirm** → creates transactions with `source: 'sms'` and stores their keys.
5. **Auto-import on app start** (if `smsAutoImportEnabled` and permission granted): silently import new matches → SnackBar "تم استيراد 3 حركات من الرسائل 📩".
6. **Unknown sender fallback**: Settings → "أضف مرسل محفظة" → user picks an SMS conversation → its address is added to the registry mapped to a wallet.
7. **iOS**: every SMS entry point is hidden (`Platform.isAndroid` checks); the app remains fully functional with manual entry.

**Done when:** with test SMS in the inbox matching the templates, the wizard previews them correctly, imports only the confirmed ones without duplicates on re-scan, and imported rows appear with `source: 'sms'` and the 📩 badge. On iOS, no SMS UI appears anywhere.

---

### Step 7 — Stats & Rule-Based Insights (NO AI)
1. `fl_chart` pie: spending by category (this month). Bar: daily spending (week/month toggle).
2. Insight cards (simple arithmetic in `StatsCubit`):
   - Weekly comparison: `(thisWeek − lastWeek) / lastWeek` → "صرفك زاد/نقص 20%"
   - Daily average this month
   - Top spending wallet & top category
   - Suggestion: `topCategory × 0.10` → "لو خفّضت {category} 10% بتوفر {amount} شهرياً"
3. Graceful empty states ("لا توجد بيانات كافية بعد").

**Done when:** charts and insights match hand-verified numbers from known test data.

---

### Step 8 — Permissions + Notifications
1. Request `POST_NOTIFICATIONS` via `permission_handler` (once, on first Home entry) and from Settings. (SMS permission is requested inside the wizard in Step 6.)
2. `NotificationService`:
   - **Low-balance alert**: after any transaction insert (manual or SMS), if wallet balance < `lowBalanceThreshold` → "⚠️ رصيد {wallet} نزل عن {threshold}".
   - **Daily reminder** at 21:00: "سجّل صرفيات اليوم 📝" (toggleable).
3. Denied permissions → polite Arabic explanation + link to app settings.

**Done when:** notifications fire correctly; denying a permission never breaks the flow.

---

### Step 9 — Settings
Theme selector • biometric toggle • notifications toggle • **SMS auto-import toggle + sender management** (Android) • low-balance threshold • logout.

**Done when:** every setting persists and takes effect immediately.

---

### Step 10 — Creative Features
1. **Reconciliation**: "تحديث الرصيد الفعلي" on Wallet Details → enter the real balance → auto-creates an `adjustment` transaction for the difference.
2. **Offline banner**: "وضع أوفلاين — سيتم المزامنة لاحقاً" when there is no connectivity.

**Done when:** reconciliation fixes a deliberately wrong balance exactly.

---

### Step 11 — App Name & Icon (both platforms)
1. `android:label="ميزان"`; iOS display name `ميزان` (`CFBundleDisplayName`).
2. Place `assets/icon/app_icon.png` (1024×1024); if none is provided, generate a simple one (solid `#0E7C61` rounded square, white wallet glyph).
3. Configure `flutter_launcher_icons` for **android + ios** and run generation.

**Done when:** the installed app shows "ميزان" and the new icon in the launcher/home screen.

---

### Step 12 — Build the APK (course deliverable)
```bash
flutter analyze        // zero errors
flutter build apk --release --split-per-abi
```
- Output → rename `app-arm64-v8a-release.apk` to `mizaan-release.apk`.
- Install on a real device/emulator and smoke-test the full flow.
- (Optional, only if a Mac/Xcode is available: `flutter build ios` — not required for the course deliverable.)

**Done when:** the release APK installs cleanly and every row in Section 8 passes.

---

## 8. Course Requirements → Acceptance Checklist

| Requirement | Where | Verified by |
|---|---|---|
| Introduction screen | `/intro` | Shows on first launch only; skippable |
| Splash with self-built animation | `/splash` | Animation code uses `AnimationController`; no Lottie/Rive in pubspec |
| Home screen | `/home` | Total balance + wallets + recent transactions render live |
| Favorite screen | `/favorites` | Star a wallet → appears here; persists after restart |
| Login + authentication + biometrics | `/login`, biometric gate | Firebase email/password works; fingerprint gate on re-entry |
| Register screen | `/register` | New account created; Arabic validation errors shown |
| Theme | Settings → theme | Light/dark persists after restart |
| Permission | Notifications + **SMS** permissions | System dialogs appear; app handles grant/deny gracefully |
| Firebase | Auth + Firestore | Login works; data syncs when online |
| Local database | Hive + shared_preferences | Full offline usage works in airplane mode |
| State management | flutter_bloc (Cubit) | No `setState` for shared state |
| Creative idea | Wallet aggregation + **SMS auto-import** + reconciliation | Demo-able live |
| Change name & icon | Step 11 | Launcher shows ميزان + new icon |
| Convert to APK | Step 12 | `mizaan-release.apk` installs and runs |

---

## 9. FUTURE PHASE — Documented but NOT to be built

1. **AI financial advisor (Gemini API)**: sends an anonymized spending summary and returns natural-language advice. Would live in Stats as a "المستشار المالي" card. Requires internet.
2. **Background SMS listener**: a native Kotlin receiver that imports messages the moment they arrive, even when the app is closed. Current scope imports on app start + manual sync, which is sufficient.

---

## 10. Definition of Done

- All steps pass their "Done when" criteria, and every row in Section 8 is verified.
- `flutter analyze` → 0 errors.
- The project contains **only `android/` and `ios/`** platform folders; native Android code is **100% Kotlin**.
- SMS import works end-to-end on Android (permission → scan → preview → import → dedupe), and is completely hidden on iOS.
- App runs **fully offline** after login (airplane-mode test).
- All UI is Arabic/RTL with the bundled font.
- `mizaan-release.apk` is built and installs cleanly.
