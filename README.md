# Mizaan (ميزان)

> An offline-first financial tracker for Yemeni e-wallet users.

Mizaan is a Flutter application that helps users organize electronic-wallet balances, manual financial entries, and wallet-related SMS transactions in one explainable financial ledger.

The application is designed for users who may manage multiple wallets and may not always have a reliable internet connection.

## Overview

Wallet information is often distributed across different applications, SMS notifications, and manual notes. Mizaan provides a unified view of wallets and transactions while keeping the local database available offline.

The project focuses on:

- Offline-first financial tracking
- Arabic and right-to-left user experience
- Multiple wallet management
- Manual income, expense, and adjustment entries
- Android SMS importing for supported wallet messages
- Duplicate SMS transaction protection
- Account and guest-data isolation
- Currency-specific balance calculations
- Local storage with optional cloud synchronization

## Main Features

### Wallet and Transaction Management

- Add and manage multiple wallets
- Set an opening balance for each wallet
- Record income, expenses, and balance adjustments
- Assign categories, notes, dates, and wallet information
- View wallet-specific and global transaction history
- Filter transactions by source, including manual and SMS entries

### SMS Transaction Import

On Android, Mizaan can process wallet-related SMS messages and extract structured information such as:

- Wallet or sender identity
- Transaction type
- Amount
- Currency
- Balance when available
- Reference number when available
- Transaction date

Messages are filtered before parsing so that unknown or unrelated senders are not treated as financial transactions.

> **Platform limitation:** Automatic SMS reading is available on Android only. iOS does not allow third-party applications to read SMS messages, so iOS users can continue using Mizaan through manual transaction entry.

### Balance Calculation

Wallet balances are calculated using the following logic:

```text
wallet balance = opening balance
               + total income
               - total expenses
               ± adjustments
```

Currencies are kept separate. Yemeni Riyals, Saudi Riyals, and US Dollars are not added together as if they were the same currency.

### Reliability and Data Protection

- SMS sender filtering before parsing
- Normalized transaction identity for duplicate detection
- Protection against repeated saves during concurrent operations
- Separate local storage for guest and authenticated users
- Wallet deletion cascades to related transactions
- Raw SMS content and sender data are excluded from Firestore writes
- Local-first storage keeps core functionality available without internet

## Technology Stack

| Area | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| State management | flutter_bloc / Cubit |
| Local database | Hive |
| Settings | shared_preferences |
| Authentication | Firebase Authentication |
| Cloud synchronization | Cloud Firestore |
| Notifications | Firebase Messaging and flutter_local_notifications |
| SMS processing | telephony on Android |
| Charts | fl_chart |
| Biometrics | local_auth |
| Permissions | permission_handler |
| Formatting | intl |
| Identifiers | uuid |
| Arabic font | Cairo |

## Architecture

Mizaan follows a feature-first structure with repositories and services:

```text
lib/
├── core/
│   ├── constants/
│   ├── router/
│   ├── theme/
│   └── utils/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── features/
│   ├── auth/
│   ├── favorites/
│   ├── home/
│   ├── onboarding/
│   ├── settings/
│   ├── sms/
│   ├── splash/
│   ├── stats/
│   ├── transactions/
│   └── wallets/
├── app.dart
├── firebase_options.dart
└── main.dart
```

### Data Flow

```text
SMS or manual input
        ↓
Filtering and validation
        ↓
Parsing and duplicate protection
        ↓
Hive local database
        ↓
Balance calculation and UI update
        ↓
Firestore synchronization when online
```

Hive is the local source of truth. Firestore is used for synchronization when an authenticated user has an available internet connection.

## Requirements

- Flutter 3.44.3 or newer
- Dart 3.12.2 or newer
- Android Studio or Visual Studio Code
- Android SDK for Android builds
- Xcode and macOS for iOS builds
- A Firebase project for authentication and Firestore synchronization

Android SMS importing must be tested on a real Android device or a properly configured emulator. iOS builds do not use SMS permissions.

## Getting Started

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd mizaan
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Create or select a Firebase project and enable:

- Email/Password Authentication
- Cloud Firestore
- Firebase Cloud Messaging if push notifications are required

Then configure FlutterFire for Android and iOS:

```bash
flutterfire configure
```

Make sure the generated Firebase configuration matches the application platforms before running the project.

### 4. Run the Application

```bash
flutter run
```

To run on a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

## Testing and Quality Checks

Run the following commands from the project root:

```bash
flutter analyze
flutter test
```

The project includes tests for:

- SMS parsing and wallet recognition
- Arabic and international number formats
- Duplicate transaction detection
- Balance calculations
- Multi-currency isolation
- Account and guest-data isolation
- Authentication flows
- Widget and screen behavior
- Date picker behavior
- Statistics and reports
- Wallet balance reconciliation

### Current Validation Result

The latest local validation reported:

- **148 automated Flutter tests passed**
- **0 issues reported by `flutter analyze`**

Real-device validation is still important for SMS permissions, background SMS handling, notifications, and behavior across different Android versions.

## Building an APK

### Debug APK

```bash
flutter build apk --debug
```

### Release APK

```bash
flutter build apk --release
```

### Smaller Architecture-Specific APKs

To generate separate APK files and reduce download size:

```bash
flutter build apk --release --split-per-abi
```

The 64-bit Android APK is usually generated at:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Android SMS Testing Checklist

Test the following scenarios on a real Android device:

1. Receive a known wallet SMS while the application is open.
2. Receive a known wallet SMS while the application is in the background.
3. Receive a known wallet SMS while the application is closed.
4. Confirm that the transaction is imported only once.
5. Confirm that an unknown sender is ignored.
6. Confirm that a wallet cannot be assigned automatically when it cannot be identified.
7. Confirm that the wallet balance is updated correctly.
8. Confirm that only one notification is displayed for one incoming SMS.
9. Confirm that guest and authenticated-user data remain isolated.

## Limitations

- Automatic SMS processing is Android-only.
- SMS parsing depends on the format used by each wallet provider.
- New wallet message formats may require additional parser rules.
- Release signing must be configured before publishing a production APK.
- More real-device testing is required before production deployment.
- Durable Firestore retry and conflict handling can be improved in a future release.

## Future Improvements

- Add more wallet-provider templates
- Improve parser learning for new SMS formats
- Add export to PDF or Excel
- Add richer financial reports and trends
- Improve synchronization conflict resolution
- Add automated end-to-end tests on real Android devices
- Prepare production signing and release hardening

## Privacy Notes

Mizaan processes wallet-related messages to create structured financial records. SMS access is sensitive and should only be enabled with the user's consent.

The application uses sender filtering and does not write raw SMS body or sender information to Firestore. Developers should also review Android permissions, Firebase security rules, and release configuration before publishing the application.

## Project Status

Mizaan is a functional academic/final-project prototype with a tested core and Android SMS integration. The project is ready for demonstration and further real-device validation before production release.

## Author

**Ibrahim Alsharjabi**

## License

This project is currently intended for academic and demonstration purposes. Add a license here if the repository will be distributed publicly.
