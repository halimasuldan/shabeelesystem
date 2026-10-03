# Firebase Setup Guide — Shabelle Primary School System

## ✅ STATUS — FULLY CONNECTED & READY 🎉

| Step | Status |
|---|---|
| Firebase project | ✅ `shabelleapp-e8ffd` |
| Android + Web apps registered | ✅ |
| Config files (`options.dart`, `google-services.json`) | ✅ Real values |
| Firebase CLI login | ✅ Done on this machine |
| Email/Password authentication | ✅ Enabled |
| Firestore database | ✅ Created — `africa-south1` region |
| Security rules + indexes | ✅ Deployed |
| **Admin account** | ✅ `admin@shabelle.com` / `Shabelle@2026` |

> **Login now works:** run `flutter run` → sign in with `admin@shabelle.com` / `Shabelle@2026`.
> Admin user document: `users/bqfD3855XiRNFqjs5QfeFcueJYJ2` (role=admin, isActive=true).
> **Change this password soon** via the app or Firebase Console → Authentication → Users.

Parts 4–7 below are kept for reference only — they are already completed.

---

This guide connects the app to a **brand-new Firebase project**. Follow the steps in order.

---

## Part 1 — Create the Firebase project (browser, ~3 minutes)

1. Go to **https://console.firebase.google.com** and sign in with your Google account.
2. Click **"Create a project"** (or "Add project").
3. Project name: `shabelle-system` → Continue.
4. Google Analytics: **Disable** (not needed) → **Create project**.

## Part 2 — Register the Android app

1. In the project console, click the **Android icon** to add an app.
2. **Android package name** (must match `android/app/build.gradle.kts`):
   ```
   com.example.shabelle_system
   ```
3. App nickname: `Shabelle System` → **Register app**.
4. Download **`google-services.json`** and replace the template file at:
   ```
   android\app\google-services.json
   ```

## Part 3 — Fill in `lib/firebase/options.dart`

In the console: **Project Settings (⚙) → General → Your apps → Android app → SDK setup and configuration → Config**. You will see values like `AIzaSy...`, `1:123456789:android:abc...`.

Copy each value into `lib/firebase/options.dart`:

| Console value | options.dart field |
|---|---|
| `apiKey` | `apiKey` |
| `appId` | `appId` |
| `messagingSenderId` | `messagingSenderId` |
| `projectId` | `projectId` |
| `storageBucket` | `storageBucket` |

Replace the `YOUR_...` placeholders in **both** the `android` and `ios` constants (use the same values for iOS until you register an iOS app).

> **Alternative (automatic):** after running `firebase login` in a terminal, you can instead run:
> ```
> flutterfire configure --project=<your-project-id> --platforms=android --android-app-id=com.example.shabelle_system --yes
> ```
> This regenerates `lib/firebase/options.dart` and `android/app/google-services.json` for you.

## Part 4 — Enable Authentication

1. Console → **Build → Authentication → Get started**.
2. **Sign-in method** tab → enable **Email/Password** → Save.

## Part 5 — Create the Firestore database

1. Console → **Build → Firestore Database → Create database**.
2. Location: closest to your users (e.g. `europe-west`).
3. Start in **production mode** → Create.

## Part 6 — Deploy security rules & indexes

The repo already contains `firestore.rules`, `firestore.indexes.json`, and `firebase.json`.

In a terminal at the project root:

```powershell
firebase login            # opens the browser — do this yourself
firebase use --add        # select your project, alias: default
firebase deploy --only firestore:rules,firestore:indexes
```

> Indexes take a few minutes to build. The app queries that need them:
> notifications (userId + createdAt / userId + isRead),
> pickup_dropoff (studentId + parentUserIds[CONTAINS] + timestamp — the parent
> "Pickup & Drop-off" timeline; the `parentUserIds` filter is required because
> the security rules only expose a parent's own child's events),
> attendance (studentId/classId + date), bus_trips (driverId + startTime),
> bus_locations (tripId + timestamp), exam_results (studentId + createdAt).

## Part 7 — Create the first admin user

1. Console → **Authentication → Users → Add user** (email + password).
2. Copy the generated **UID**.
3. Console → **Firestore → Start collection**:
   - Collection ID: `users`
   - Document ID: **paste the UID**
   - Fields: `role` (string) = `admin`, `fullName` (string) = your name, `email` (string)

## Part 8 — Run the app

```powershell
flutter pub get
flutter run
```

Log in with the admin credentials from Part 7.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Failed to authenticate` from firebase CLI | Run `firebase login` again (session expired). |
| `The query requires an index` in logs | Deploy indexes (Part 6) or click the link in the error to auto-create. |
| `PERMISSION_DENIED` in Firestore | Check rules deployed and the user's `role` field in `/users/{uid}`. |
| Build error: `File google-services.json is missing` | Ensure it's at `android\app\google-services.json` with real values. |
| `Duplicate app` exception at startup | Firebase is initialized only in `main.dart` — don't call `Firebase.initializeApp` again. |
