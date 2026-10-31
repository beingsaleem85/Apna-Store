# Apna Store — Multi-Vendor Marketplace Platform

Apna Store is a Flutter-based multi-vendor e-commerce platform featuring Buyer, Seller Center, and Super Admin portals powered by Supabase Auth, PostgreSQL database, and Storage.

---

## 1. Project Setup & Prerequisites

### Prerequisites
- **Flutter SDK:** `3.44.x` or later
- **Dart SDK:** `3.12.x` or later
- **Web Browser:** Google Chrome or Microsoft Edge (for Web target)
- **Android SDK:** (for Android APK build target)

---

## 2. Environment Configuration

Application credentials and configurations are loaded dynamically at runtime via `--dart-define` flags.

### Supported Environment Parameters

| Variable | Description | Example |
|---|---|---|
| `SUPABASE_URL` | Supabase Project URL | `https://xyz.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase Anonymous / Publishable Key | `sb_publishable_...` |
| `APP_ENV` | Application environment mode (`development`, `staging`, `production`) | `development` |

A sample environment configuration file is provided in [`.env.example`](file:///.env.example).

> **SECURITY NOTICE:**  
> Never hardcode service-role keys or production secrets in source code or commit them to version control.

---

## 3. Running & Building the Project

### Run Locally (Web)
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_ENV=development
```

### Run Tests
```bash
flutter test \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_ENV=development
```

### Build Web Package
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_ENV=production
```

### Build Android APK (Debug)
```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=APP_ENV=development
```

---

## 4. Repository Structure

```text
apna-store/
├── lib/
│   ├── app/                         # App core entry & themes
│   ├── core/
│   │   ├── config/                  # AppConfig (Environment configuration)
│   │   ├── constants/               # Theme tokens & UI constants
│   │   ├── models/                  # Shared domain DTOs
│   │   ├── routes/                  # AppRouter navigation definitions
│   │   ├── services/                # Supabase & App state services
│   │   └── widgets/                 # Shared UI components
│   └── features/
│       ├── admin/                   # Legacy admin screens
│       ├── auth/                    # Authentication UI
│       ├── buyer/                   # Buyer portal screens
│       ├── seller/                  # Seller center UI & onboarding
│       └── super_admin/             # Super Admin management screens
├── supabase/
│   └── migrations/                  # Versioned SQL migrations
├── docs/
│   └── CURRENT_STATE_AUDIT.md       # Baseline audit & state tracking
└── .env.example                     # Environment template example
```

---

## 5. Verification Commands

To verify application code health, formatting, tests, and build outputs:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```
