# Lifting Life — Train. Progress. Compete. Inspire.

A complete, modern Flutter fitness application combining **360° Interactive 3D Exercise Biomechanics**, **Bodybuilding & Powerlifting Workout Tracking**, **TikTok-Style Short-Form Fitness Community**, **Fair-Play Friend Leaderboards**, and **Fitness Courses with Mandatory App-Owner Approval**.

---

## 1. Architecture & Project Structure

- **Design System**: [app_theme.dart](lib/app_theme.dart) — Deep Black (`#0B0F14`), Dark Charcoal (`#171C24`), Electric Lime (`#B8FF3B`), Cyber Cyan (`#00E5FF`), Strength Amber (`#FFB800`).
- **Database Schema & RLS / Triggers**: [schema.sql](supabase/schema.sql) — 31 PostgreSQL / Supabase tables with Row-Level Security and the `enforce_course_approval_rules()` trigger preventing self-approval and reverting edited courses to `pending_review`.
- **Interactive 3D Exercise Viewer**: [exercise_3d_viewer.dart](lib/widgets/exercise_3d_viewer.dart) — Real-time 3D perspective projection, 360° drag rotation, Front/Side/Rear/3D Iso camera presets, Zoom controls, Speed (`0.5x`–`2.0x`), Scrubber timeline, Primary/Secondary muscle heatmaps, and Movement Trajectory path curves.
- **210+ Seeded Gym Exercise Library**: [exercise_seed_data.dart](lib/data/exercise_seed_data.dart) — Covers all 12 muscle groups and 6 equipment categories with step-by-step instructions, safety tips, common mistakes, and alternatives.
- **Core Screens**:
  - [main_layout.dart](lib/main_layout.dart) — Responsive 5-tab bottom navigation (`Home`, `Exercises`, `Workout`, `Rankings`, `Profile`) + desktop `NavigationRail`.
  - [dashboard_screen.dart](lib/screens/dashboard_screen.dart) — Home Dashboard with 3D Exercise Spotlight, SBD Total, Notifications, and quick links to Courses & Owner Approvals.
  - [exercises_screen.dart](lib/screens/exercises_screen.dart) — Searchable, filterable 210+ exercise catalog and full Exercise Detail + 3D Viewer screen.
  - [workouts_screen.dart](lib/screens/workouts_screen.dart) — Active Workout Logger (sets, weight, reps, RPE/RIR, warm-ups, auto rest timer, templates), Bodybuilding System (PPL, Upper/Lower, Full Body, Bro Split, Custom), Powerlifting SBD System (1RM & Percentage Calculator, 5/3/1, Block Periodization, Linear Progression, Competition Variations), and Workout History.
  - [rankings_screen.dart](lib/screens/rankings_screen.dart) — 6 Leaderboard categories, frequency-capped XP fairness (max 5 weekly sessions counted for XP), QR/invite code, friend search, Challenges, and TikTok-Style Social Fitness Feed.
  - [courses_screen.dart](lib/screens/courses_screen.dart) — Course Catalog, Interactive Learning & Quiz screen, Creator Studio (`Draft` -> `Pending Review`), and Approval Status Tracker.
  - [admin_dashboard_screen.dart](lib/screens/admin_dashboard_screen.dart) — Protected Owner/Admin Dashboard for Course Review & Approval (`Approve`, `Request Changes`, `Reject`), Abuse Moderation, Exercise DB Management, and Immutable Audit Logs.
  - [analytics_screen.dart](lib/screens/analytics_screen.dart) — Custom-painted 1RM Strength Progression and Weekly Hypertrophy Volume charts.
  - [auth_onboarding_screen.dart](lib/screens/auth_onboarding_screen.dart) & [profile_screen.dart](lib/screens/profile_screen.dart) — Authentication, RBAC Role Switcher, Privacy Controls, Quiet Hours, JSON Data Export, and Account Deletion.

---

## 2. Running the App Locally

```bash
cd tp1
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## 3. External Services, 3D Assets & Credentials Configuration

To connect production cloud services, supply the following credentials and assets:

1. **Supabase Auth & OAuth Providers (Facebook, Apple ID, Email)**:
   - Run [supabase/schema.sql](supabase/schema.sql) in your Supabase SQL Editor (creates `users`, `linked_auth_providers`, and all 31 relational tables).
   - Supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `--dart-define`.
   - **Facebook Login SDK & OAuth**: Configure your Meta App ID & Client Token in the Facebook Developer Console, enable Facebook under *Supabase → Authentication → Providers*, and register the OAuth callback URL `https://<project-ref>.supabase.co/auth/v1/callback` plus custom URL scheme `liftinglife://login-callback`.
   - **Sign in with Apple**: Enable the *Sign in with Apple* capability on your Apple Developer Service ID, configure Apple Private Email Relay (`@privaterelay.appleid.com`), and add the Apple `.p8` key to Supabase Auth.
   - Assign the `owner` role in the `user_roles` table server-side (never via client email input).
2. **External GLB/glTF 3D Mesh Assets**:
   - The built-in `Exercise3DViewer` renders a real-time 3D articulated biomechanical avatar out of the box with zero external dependencies, and maps each exercise to `assets/models3d/<movement_pattern>.glb` when custom `.glb` meshes are placed in `assets/models3d/`.
3. **TikTok Share & OAuth Integration**:
   - Uses standard system share sheets and opt-in `@username` discovery. Official TikTok Login Kit / Share Kit requires a registered TikTok Developer Client Key (`TIKTOK_CLIENT_KEY`).
