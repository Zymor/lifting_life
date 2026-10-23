# Lifting Life — AI Agent 1 & AI Agent 2 Integration Contracts

## 1. Ownership Boundaries
- **AI Agent 1 (Backend, Auth, Database, Cloud Storage & Security)**:
  - `lib/core/configuration/supabase_config.dart`
  - `lib/core/security/secure_session_storage.dart`
  - `lib/core/security/demo_data_cleanup_service.dart`
  - `lib/core/storage/cloud_storage_service.dart`
  - `lib/core/contracts/agent2_exercise_3d_contract.dart`
  - `lib/services/data_service.dart`
  - `supabase/migrations/20261021000001_complete_production_schema.sql`
  - `supabase/migrations/20261021000002_row_level_security_policies.sql`
  - `supabase/migrations/20261021000003_storage_buckets_and_policies.sql`
  - `supabase/migrations/20261021000004_safe_demo_cleanup_procedure.sql`
- **AI Agent 2 (3D Anatomy Avatar, Gym Equipment, Exercise Animations & Fitness UI)**:
  - `lib/widgets/exercise_3d_viewer.dart` (Untouched by AI Agent 1)
  - `lib/screens/exercises_screen.dart` (Untouched by AI Agent 1)

---

## 2. Dart Interface Contract for AI Agent 2
`DataService.instance` implements `Agent2ExerciseAnd3DContract` (`lib/core/contracts/agent2_exercise_3d_contract.dart`):

```dart
final contract = DataService.instance as Agent2ExerciseAnd3DContract;

// 1. Query authorized exercises with optional filters
final exercises = await contract.fetchAuthorizedExercises(
  category: 'Chest',
  equipment: 'Barbell',
);

// 2. Resolve 3D GLB paths, short-lived signed video URLs, and muscle activation ratios
final bundle = await contract.resolveExercise3DAssets('ex_bb_bench_press');

// 3. Refresh an expired signed URL (15-minute TTL)
final freshUrl = await contract.refreshSignedAssetUrl(
  bucketId: 'exercise-videos',
  objectPath: bundle.anatomyAvatarGlbPath,
);
```

---

## 3. Cloud Storage Bucket Hierarchy (`CloudStorageService`)
All 9 buckets are private (`public = false`) with Row-Level Security (RLS) enforced on `storage.objects`:

| Bucket ID | Path Convention | Allowed Formats | Max Size |
| :--- | :--- | :--- | :--- |
| `profile-avatars` | `users/{userId}/avatar/{avatarId}.webp` | `.webp`, `.png`, `.jpg` | 5 MB |
| `exercise-videos` | `exercises/{exerciseId}/video/{angle}.mp4` | `.mp4`, `.webm` | 150 MB |
| `anatomy-models` | `anatomy/{modelId}/avatar.glb` | `.glb` | 50 MB |
| `exercise-equipment` | `equipment/{equipmentId}/model.glb` | `.glb` | 50 MB |
| `machine-models` | `machines/{machineId}/rigged_machine.glb` | `.glb` | 65 MB |
| `course-media` | `courses/{courseId}/lessons/{lessonId}/media.mp4` | `.mp4`, `.webp`, `.png`, `.pdf` | 250 MB |
| `community-media` | `posts/{userId}/{postId}/clip.mp4` | `.mp4`, `.webp`, `.png`, `.jpg` | 100 MB |
| `private-user-files` | `users/{userId}/exports/{exportId}.json` | `.json`, `.pdf` | 25 MB |
| `import-staging` | `staging/{batchId}/{fileName}` | `.glb`, `.mp4`, `.webp`, `.json` | 250 MB |

---

## 4. External Credentials Required for Live Cloud Deployment
Pass via `--dart-define` at build/run time (never hardcode in source code):
- `SUPABASE_URL`: HTTPS URL of the production Supabase project
- `SUPABASE_ANON_KEY`: Public anonymous JWT key (service-role keys are rejected by `SupabaseConfig.validateConfiguration()`)
- `APP_ENV`: `production` | `staging` | `development`
- `FACEBOOK_APP_ID`: Meta Developer OAuth App ID
- `APPLE_SERVICES_ID`: Apple Developer Services ID for Sign in with Apple
- `RESEND_API_KEY`: Transactional email API key for 6-digit OTP delivery

