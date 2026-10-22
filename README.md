# Lifting Life — Complete Platform Suite

Welcome to the **Lifting Life** production platform suite.

## Architecture Overview

| Component | Path | Technology | Default Port | Role |
| :--- | :--- | :--- | :--- | :--- |
| **Website 1 (User Website & App)** | [`tp1/`](file:///c:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/Lifting%20Gym/tp1) | Flutter 3.x (Web, iOS, Android) | `8080` (Web) | Athlete platform: workouts, nutrition, 5,600+ exercises, real auth |
| **Website 2 (Admin Portal)** | [`lifting-life-admin/`](file:///c:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/Lifting%20Gym/lifting-life-admin) | React 19 + Vite | `3000` | SaaS admin portal: MFA TOTP, RBAC, users, catalogue, audits |
| **Authorized Backend Engine** | [`lifting-life-backend/`](file:///c:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/Lifting%20Gym/lifting-life-backend) | Node.js Express + SQLite | `4000` | Central REST API, PBKDF2 auth, TOTP verification, SQLite persistence |

---

## Quick Start (One-Click)

Double click [`start-platform.bat`](file:///c:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/Lifting%20Gym/start-platform.bat) in the root directory. This will start:
1. Backend on `http://localhost:4000`
2. Admin Portal on `http://localhost:3000`
3. Lifter App on `http://localhost:8080`

Or run manually:

```bash
# 1. Start Backend
cd lifting-life-backend
npm start

# 2. Start Admin Portal
cd lifting-life-admin
npm run dev

# 3. Start Lifter App
cd tp1
flutter run -d chrome --web-port 8080
```

---

## Super Admin Credentials & MFA

- **Email**: `admin@liftinglife.com`
- **Password**: `SuperAdminKey2026!`
- **TOTP MFA Secret**: `RRSMM7435R54GJIOHZ4VMT5YZHO3JDYN` *(Add to Google Authenticator, Authy, or 1Password)*
- **Emergency Backup Codes**:
  - `FFC6-00D8`
  - `61CD-EDDA`
  - `D60E-5492`
  - `E609-FA43`
  - `FAAE-718A`
  - `B877-E4A3`
  - `DC00-1AA3`
  - `B5FD-4D48`

---

## Verification & Test Status

- **Flutter User App (`tp1`)**: `flutter analyze` $\rightarrow$ **0 issues**; `flutter test` $\rightarrow$ **74 / 74 tests passing (100%)**
- **Admin Portal (`lifting-life-admin`)**: `npm run build` $\rightarrow$ **0 errors (clean Vite production bundle)**
- **Authorized Backend (`lifting-life-backend`)**: `npm test` $\rightarrow$ **5 / 5 suites passing (100%)**

