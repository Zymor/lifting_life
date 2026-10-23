# Lifting Life integration report — 2026-10-22

## Project boundary and backup

`tp1` remains the Flutter application. `openGym-main` is unchanged and is not a runtime dependency. No third application was created.

Pre-change backup: `../tp1_backup_20261022_230035`. It includes source, assets, platform projects, configuration and local project files; generated `build`, `.dart_tool`, and `.git` directories were excluded. An older `tp1_backup_original` was left untouched. No external Supabase database or device storage was modified or backed up by this operation.

## Inspection and integration decisions

The recursive source inventory is in `integration-file-inventory.txt`. Inspection covered the Flutter entry point, navigation, exercise/workout/program models, data and secure-storage services, auth configuration, screens, SQL migrations and regression tests; and OpenGym's README, package manifests, notices, catalogue schema, feature list, frontend views and workout semantics. The inventory is not a claim that every source line or every upstream test was reviewed.

| Area | Existing tp1 | OpenGym integration decision and result |
|---|---|---|
| Architecture | Flutter / Material, DataService, Supabase Auth and Storage | Kept. No React, Capacitor, Node server, duplicate auth or database added. |
| Dashboard/navigation | Responsive navigation, dashboard, courses, nutrition, analytics | Kept; planner connected from dashboard and profile. |
| Exercise library | Original seeded library, search and anatomy guidance | Bundled all 6,554 upstream JSON text records; resolves variant aliases; deduplicates names, preserving original tp1 IDs and entries. Equipment filters now derive from the combined library. |
| Exercise media | Existing tp1 anatomy/technique components and asset descriptors | OpenGym media excluded. Imported entries show honest text-only guidance, including in the workout logger. Existing placeholder GLBs are not upgraded into real animations by this merge. |
| Programs | PPL, Upper/Lower, Full Body and powerlifting prescriptions | Kept; saved templates can be assigned to days and rotation. Existing workout/program UI remains. |
| Calendar | Placeholder | Implemented date selection, weekday assignments, dated overrides/rest days and resetting an override. |
| Rotation | Missing | Ordered routine list with explicit next-routine advancement and persistence. Automatic advancement after completion is not implemented. |
| Training | Sets/reps/load, RPE/RIR, warm-ups, rest timer, plates | Kept; duration/distance editing added. Starting templates/history now uses current owner, fresh IDs/time and incomplete sets, and protects an active draft. |
| History | Read-only cards and duplicate action | Review/correct names, notes, dates, reps and weight; recompute records without awarding XP again. |
| Progression | Existing program guidance | Added conservative double-progression suggestions in history review; incomplete/missed sets never increase load. Other OpenGym progression engines are not ported. |
| Measurements | Profile body weight | Added dated body-weight log with validation and deletion in planner. It does not overwrite profile weight. |
| Analytics | Existing strength and volume charts | Fixed date filtering of workout-derived summaries/charts. Existing PR summary remains lifetime-oriented. |
| Persistence | Workouts, drafts, PRs and profile | Added restoration/isolation of favorites, templates, meals, goals, custom foods and nutrition targets; planner uses a new user-scoped collection. Native write failures are no longer silently accepted as durable writes. |
| Exports | Profile/workouts/PR JSON | Expanded to templates, favorites, draft, nutrition, goals and training plan/measurements. |
| Cloud | Supabase authentication and protected storage | Added explicit private snapshot backup and additive RLS migration. No automatic cross-device merge or restore UI is claimed. |
| Branding | Most Flutter screens already Lifting Life | Updated web/PWA, Android/iOS/macOS/Linux/Windows display metadata. Package name, application IDs and storage keys retained to avoid breaking existing data/install identity. |

## License decisions

Read `openGym-main/LICENSE`, `NOTICE.md`, `catalogue/README.md`, and `catalogue/media/NOTICE.md` before transfer.

- OpenGym's code and community catalogue text are AGPL-3.0. The imported text retains the original attribution and license in `assets/licenses/` and in the in-app license page.
- ExerciseDB-origin text has the MIT notice reproduced in the upstream NOTICE. This does not turn the full catalogue, descriptions or translations into MIT material.
- Gym visual images, clips and animations explicitly prohibit extraction/integration into independent apps without a separate license. None were copied, hotlinked, opened as visual references, or used for generated assets.
- The catalogue is aggregated into JSON and adapted to Flutter categories and stable `opengym_` IDs by Lifting Life integration changes dated 2026-10-22. Native planner/editor/progression code was implemented for tp1; no React frontend or Node backend was pasted into it.
- AGPL material remains AGPL. Distribution of the combined derivative must satisfy the applicable copyleft, attribution and corresponding-source requirements. Before public/network distribution, make the corresponding source available and provide its real location to users; this task did not publish a repository or deploy the app. See https://www.gnu.org/licenses/agpl.html and the bundled license. Do not represent this build as wholly permissive/proprietary-licensed.

## Running entirely from tp1

```powershell
cd tp1
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/production.json
```

Create `config/production.json` from `config/production.example.json`, supplying the actual public Supabase URL/key. Never put a service-role key in the client. Follow the existing auth/SQL deployment documentation for the original schema; do not rerun destructive schema scripts against a populated database. Apply `supabase/migrations/20261022000001_training_backups.sql` after reviewing it for your target project to enable the new backup action. The migration creates only a new table/policy and does not alter existing user tables.

The configuration examples currently contain no live project credentials. Existing debug-only development login remains available for development tests; release builds do not populate fake activity/history. Missing credentials do not produce fake successful registration or email delivery.

```powershell
flutter build web --release --dart-define-from-file=config/production.json
```

Use `build/web` with HTTPS (or localhost) for secure browser storage. Browser/device data stays on that device until exported or explicitly backed up. Use Profile > Export Personal Data for the complete local snapshot. Profile > Back up training to Supabase requires real authentication and the new migration.

## Verification and remaining work

See `test-results.txt` for executed regression tests. Verification includes real Flutter dependency installation, static analysis, release web compilation, asset catalogue loading, narrow-screen planner interaction, session restart safety, user isolation, persistent data restoration, progression and history correction tests. Auth tests use a controlled backend; they do not prove live SMTP delivery.

This is a working incremental integration, **not complete feature parity with OpenGym**. These items remain unported/unverified:

- Proprietary exercise animation/video library (requires independent licensed media or newly authored demonstrations).
- Advanced drop/rest-pause/superset and unilateral logging, Greyskull/triple/time progression, deload/stall automation, recovery/structural-balance maps, activity heatmap, bodyweight goal charts and progress-photo comparison.
- OpenGym/Strong/Hevy/FitNotes/Apple Health importers, plan file/PDF sharing, custom exercise media upload, gym QR membership cards, device pairing/passkeys, 19-language UI/catalogue translations, AI coach/MCP integration, push notifications and field-level multi-device sync.
- Migration of OpenGym user data: its reference directory was not treated as an active user database. No account/workout data was imported speculatively.
- Live Supabase connection, SQL/RLS execution, registration/verification delivery, OAuth, cloud backup and cross-device operations: credentials and a deployment environment were not available. The new cloud backup endpoint is implemented but its migration is not applied remotely.
- Production account deletion and some existing social/course/admin features need a separate backend audit; existing local methods should not be assumed to implement remote deletion or moderation.
- Native device runtime/secure storage and iOS/macOS/Linux builds require their platform environments. Web compilation and widget tests do not verify all platform plugins.
- Existing imperial unit handling needs a complete conversion audit; canonical stored weights and the new history/measurement tools use kg.

No production deployment, remote database mutation, external message or publication was performed.

## Final verification — 2026-10-23 (Asia/Phnom_Penh)

| Command (working directory: tp1) | Result |
|---|---|
| `flutter pub get` | Passed; 12 newer dependency releases were outside current constraints, with no forced upgrades. |
| `flutter analyze` | Passed, no issues. See `analyze-results.txt`. |
| `flutter test --reporter expanded` | Passed, 65 tests. See `test-results.txt`. |
| `flutter build web --release --dart-define=ENABLE_DEMO_ACCOUNT=false` | Passed. Output `build/web`; see `web-build-results.txt`. |
| `flutter build apk --debug --dart-define=ENABLE_DEMO_ACCOUNT=false` | Passed. Output `build/app/outputs/flutter-apk/app-debug.apk`; see `android-build-results.txt`. |

The APK is a debug-signed build, not a store release. Neither build contains production Supabase credentials; supply your own configuration and rebuild for live authentication. Native installation/device interaction was not performed.

A comparison against the session backup found 21 modified existing source/configuration files and zero missing original source files (generated caches excluded). New integration files are additional. See `modified-existing-files.txt`. Runtime source/assets do not reference `openGym-main`.

During verification, variant-only catalogue records, a test's fake-clock wait, and an immediate-logout persistence-order race were found and corrected. The final suite above passed after those corrections. Completed workout storage is written before its recoverable draft is cleared; login waits for pending per-user state writes. Workout completion now awaits persistence before reporting a successful save.
