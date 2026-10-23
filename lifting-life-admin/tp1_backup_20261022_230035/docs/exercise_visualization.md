# Exercise Visualization — Implementation Notes (Agent 2)

Last updated: 2026-10-21

This document is the coordination artifact for **Agent 1** (auth, security, database,
storage). It records what the exercise-visualization layer currently does, what is
missing, and which shared interfaces need decisions.

---

## 1. Renderer reality (read this first)

The "3D" exercise view is **not** a GLB renderer. There is no 3D engine dependency in
`pubspec.yaml`. The avatar, equipment and animation are produced by a Flutter
`CustomPainter` (`_MuscularAnatomy3DPainter` in `lib/widgets/exercise_3d_viewer.dart`)
that:

- computes a joint rig in world units for 18 movement patterns,
- rotates/projects that rig to the canvas (yaw + pitch + zoom),
- draws muscle bellies as fusiform shapes with activation tiers,
- draws vector gym equipment in two depth layers around the body.

`AnatomyAssetCache.glbHasRenderableContent()` now parses each GLB's JSON chunk and
reports whether it contains meshes or animations. When it does not, the viewer shows
**"3D demonstration not available yet — showing the anatomical illustration."** and the
status badge reads `ILLUSTRATION MODE`.

### Current asset inventory (verified by parsing every file)

| Asset | Size | meshes | animations | skins | Verdict |
|---|---|---|---|---|---|
| `assets/models/lifting_life_anatomy.glb` | 548 B | 0 | 0 | 0 | **empty stub** |
| `assets/animations/*.glb` (14 files) | ~540 B each | 0 | 0 | 0 | **empty stubs** |
| `assets/data/muscle_mapping.json` | present | — | — | — | usable metadata |
| `assets/images/anatomy_reference.png` | present | — | — | — | artist reference only |
| Equipment models | **none** | — | — | — | missing |
| Exercise videos (MP4) | **none** | — | — | — | missing |

Every stub contains a single empty node named `LiftingLife_Anatomy_Root`. They must not
be presented to users as working 3D assets, and `Exercise.has3dAnimation = true` on
seeded exercises is not evidence that an asset exists.

---

## 2. What the vector renderer draws today

Equipment is selected from `exercise.equipment` + `exercise.movementPattern`, and is
anchored to the rig's hand / foot / shoulder joints so it travels with the animation.

| Equipment | Rendered components | Patterns supported |
|---|---|---|
| Barbell | Olympic bar, knurling, loaded plates, collars, J-hooks, power rack, flat bench | squat, bench, deadlift, hinge, overhead_press, row, curl, tibialis_raise |
| Dumbbell | Matching pairs with handles and heads, held at each hand | curl, lateral_raise, fly, bench, overhead_press, row, hinge |
| Cable | Upright, weight stack with selection pin, pulley arm/wheel, seat, cable run, lat bar / rope / single handle | pulldown, pushdown, row, pullup |
| Machine | Leg-press sled + footplate + weight horns; calf-raise platform + shoulder pads; pulldown/row station; overhead-press seat + uprights; bench-press frame | leg_press, calf_raise, pulldown, row, overhead_press, bench |
| Bodyweight | Pull-up bar with mounts | pullup |
| Resistance Band | Band line from floor anchor to hands | any pattern |

Everything is vector/greyscale with the app's steel palette, so no unrelated machine is
decoratively placed next to the athlete.

---

## 3. Missing assets required for real 3D (Task 9 structure)

Nothing below exists yet. Provide licensed files; do not rename stubs into place.

```
assets/
  images/
    anatomy_reference/            # supplied reference already in assets/images
  models/
    avatar/faceless_anatomy.glb   # REQUIRED: rigged humanoid, ~1.7m, muscle groups as
                                  #           named materials/meshes, faceless head
    barbells/olympic_barbell.glb  # bar, plates (5/10/15/20/25 kg), collars
    benches/flat_bench.glb        # + adjustable bench
    racks/power_rack.glb          # squat rack + power rack
    cables/cable_station.glb      # crossover, stack, pulleys, handles
    machines/<machine>.glb        # leg_press, smith, chest_press, shoulder_press,
                                  # leg_extension, seated_leg_curl, lying_leg_curl,
                                  # pec_deck, rear_delt, assisted_pullup, hack_squat,
                                  # calf_raise, hip_thrust, seated_row
  animations/
    bodybuilding/*.glb            # curl, lateral_raise, fly, pushdown, ...
    powerlifting/*.glb            # squat, bench, deadlift, pause variants
    machines/*.glb                # leg_press, leg_extension, leg_curl, ...
    bodyweight/*.glb              # pullup, dip, crunch
  data/
    exercise_muscle_mapping.json  # muscle ids -> primary/secondary per exercise
    equipment_mapping.json        # exercise id -> equipment/machine/animation assets
```

### Animation clips needed per movement pattern

`squat, bench, deadlift, hinge, overhead_press, curl, pulldown, pullup, row,
leg_press, lunge, lateral_raise, pushdown, dip, calf_raise, crunch, tibialis_raise,
fly`

Each clip must be a real skeletal animation on the avatar rig, with equipment
attachments declared (hand bones for bars/dumbbells, foot bones for the leg-press
footplate, shoulder bone for the squat bar).

### Video library

Licensed MP4s from the purchased Gym Animations pack. MP4 files are pre-rendered video
only; they must never be shown as a rotatable 3D avatar. Any video asset needs a
`video_url` + license reference.

---

## 4. Proposed schema changes for Agent 1 (do not apply unilaterally)

Additive columns on the exercises table (or an `exercise_assets` join table keyed by
`exercise_id` + `asset_kind`):

| Column | Type | Purpose |
|---|---|---|
| `avatar_model_path` | text | storage key for the faceless rigged GLB |
| `equipment_model_paths` | jsonb | `{barbell: key, bench: key, rack: key}` |
| `machine_model_path` | text | machine GLB key for this exercise |
| `animation_clip_path` | text | GLB animation key |
| `equipment_attachment` | jsonb | bone/offset data per asset |
| `video_url` | text | licensed MP4 URL |
| `video_license_ref` | text | license/provenance for audit |
| `asset_verified_at` | timestamptz | set only after the GLB passes mesh/animation validation |

Storage conventions to confirm with Agent 1: bucket id, signed-URL helper name, and
whether asset metadata lives on `exercises` or in a dedicated table.

### Interface contract status

`lib/core/contracts/agent2_exercise_3d_contract.dart` declares
`fetchExercises`, `fetchExerciseById`, `fetchWorkoutHistory`, `fetchPersonalRecords`,
`saveWorkoutData`, `saveActiveWorkoutDraft`, `fetchExerciseVideoAsset`,
`fetchAnatomyModelAsset`, `fetchEquipmentAndMachineAssets`, plus
`Exercise3DAssetBundle`, `MuscleActivationDescriptor` and `StorageBucketId`.

`DataService` does not implement these yet, and depends on members that do not exist
(`SecureSessionStorage.activeSessionKey`, `clearUserScopedData`, `UserRole.canManageExercises`,
`SupabaseConfig.isTestEnvironment`, `CloudStorageService.createSignedDownloadUrl`,
`exerciseVideoPath`, `anatomyModelPath`, `machineModelPath`). This is Agent 1's scope.

---

## 5. Build status

`flutter analyze` is clean as of 2026-10-21 23:2x (0 issues) and
`flutter test test/anatomy_viewer_preview_test.dart` passes.

Earlier in the session the project did not compile: `DataService` had not yet
implemented `Agent2ExerciseAnd3DContract` and several auth/storage helpers were missing
(`SecureSessionStorage.activeSessionKey`, `clearUserScopedData`,
`UserRole.canManageExercises`, `SupabaseConfig.isTestEnvironment`,
`CloudStorageService.createSignedDownloadUrl`/path helpers, `StorageBucketId`).
Those were resolved by Agent 1's side; no changes to auth, security, or schema were
made by Agent 2.

The interface contract in `lib/core/contracts/agent2_exercise_3d_contract.dart` still
describes the intended asset-fetch API. When real GLB/video assets are provisioned,
`fetchAnatomyModelAsset`, `fetchEquipmentAndMachineAssets` and
`fetchExerciseVideoAsset` are the integration points.

---

## 6. Preview / verification

`test/anatomy_viewer_preview_test.dart` renders five exercises (barbell squat, bench,
deadlift, dumbbell curl, cable pulldown, machine leg press, calf raise, pull-up) to
`build/previews/*.png`. It requires a compiling `DataService`.

An isolated harness (same viewer code + a stubbed data service) is available at
`C:\Users\Reatanak\AppData\Local\Temp\opencode\anatomy_preview` and produces
`build/previews/equipment_contact_sheet.png` without touching Agent 1 files.
