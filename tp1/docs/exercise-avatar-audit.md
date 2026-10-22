# Lifting Life exercise viewer audit — 22 October 2026

Follow-up: the exact 45-Degree Back Extension now has an original animated 2D technique diagram in `lib/widgets/back_extension_diagram.dart`. The missing-3D findings below still apply; this follow-up does not mark the other exercises available.

## Outcome and limits

Actual source and asset-manifest changes were made in `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/`.
The misleading procedural demonstrations have been replaced with explicit unavailable states, exact-variation equipment information, and six reference-backed written guides.

**No exercise animation has been corrected or biomechanically validated.** All 15 requested exercise families remain unavailable as animated demonstrations. The requested genuine 3D upgrade is incomplete because this project contains no usable character, skeletal animation or equipment geometry, and no renderer that consumes those assets. This is the fallback explicitly requested for that situation.

No accounts, workouts, courses, cloud records or original GLB/image assets were deleted. No assets were bought or published. The prior viewer source is preserved at `C:/Users/Reatanak/Documents/Codex/2026-10-22/c-users-reatanak-onedrive-desktop-i4-2/work/avatar-backup/exercise_3d_viewer.dart.txt`.

## What was wrong

- The previous viewer projected procedural world coordinates onto Flutter Canvas. It drew muscles and equipment as 2D paths; it was not a skinned 3D renderer.
- The base GLB is 548 bytes. The fourteen animation GLBs are 532–556 bytes each. Every file has a JSON scene/root node with descriptive names in extras, but no top-level meshes, skins, animations or buffers. Names such as animationClip were metadata, not motion.
- Pull-ups and pulldowns shared joint formulas. The pull-up bar was positioned from the moving hands, so the bar moved instead of remaining fixed while the body rose.
- Leg presses reused a standing lunge calculation.
- Leg extension and seated, prone, standing and band leg curls were all classified as leg_press.
- Fly/lateral raise and dip/pushdown pairs reused inappropriate motion branches.
- Independently interpolated joint coordinates changed apparent limb lengths; there was no fixed-length skeleton, skin weighting or contact solver.
- Unknown movement patterns selected a squat file. Seed entries advertised has3dAnimation=true even though their assets were placeholders.
- A JSON-content probe could mark a GLB ready without the viewer ever rendering that GLB.

## Changes

- Replaced the procedural viewer with a responsive dark/green guide and an explicit demonstration-unavailable message. No misleading play, timeline or camera controls are displayed.
- Preserved the public widget constructor interface used by existing screens. Camera and playback parameters intentionally do not enable the unavailable renderer.
- Added a 14,785-byte JSON catalog covering exactly 15 exercise variants. Lookup requires the exact exercise name and equipment; broad patterns do not borrow another variation's instructions.
- Added equipment-part labels for all 15 variants. Six guides expose written setup/movement cues with their source. Nine draft cues stay out of the UI pending review.
- Added optional qualitative muscle-group text with a legend stating that it is not measured activation.
- Added a static loading state, an eight-second load timeout and a working retry for guide-load errors. A successful small text catalog is cached; failures are not permanently cached. No GLBs or rendering surfaces are loaded.
- Disabled placeholder animation availability in seed data and changed the model default to false. Unknown patterns return no animation asset.
- Gave leg extensions and seated/prone/standing/band leg curls distinct pattern identifiers, retaining existing exercise IDs and records.
- Removed misleading 3D availability labels from library, dashboard, workout and feed entry points.

## Exercise-by-exercise status

All rows below mean **equipment guide added; animated demonstration unavailable**. These are future visual-review requirements, not completed checks.

| Exercise variant | Required movement/contact review |
|---|---|
| Barbell Back Squat | Fixed foot contacts; bar on upper back; consistent limb lengths through descent and ascent. |
| Barbell Bench Press | Bench supports head, upper back and pelvis; feet contact floor; hands stay on bar. |
| Conventional Barbell Deadlift | Plate radius determines floor contact; separate lift and controlled floor return. |
| Romanian Deadlift (RDL) | Top-start hinge clip, distinct from floor-start deadlift; no mandatory floor touch. |
| Barbell Overhead Press (OHP) | Head clears bar path; coordinated shoulders and elbows; stable feet. |
| Bent-Over Barbell Row | Stable hip hinge; fixed hand grip; bar clears knees and torso. |
| Wide-Grip Cable Lat Pulldown | Seated body stays supported; handle moves; cable stays connected and stack follows. |
| Strict Bodyweight Pull-Ups | Hands and bar fixed in world space; body rises and lowers; no pulldown reuse. |
| Barbell Biceps Curl | Forearms rotate about elbows; wrists align with grip; bar stays in both hands. |
| Rope Cable Triceps Pushdown | Elbow extension distinct from dips; rope ends follow hands; stack follows cable. |
| Dumbbell Lateral Raise | Stable upper-arm and forearm lengths; dumbbells anchored to hands; no fly reuse. |
| 45-Degree Sled Leg Press | Sled constrained to rails; seat fixed; feet contact plate; no lunge pose. |
| Seated Leg Extension Machine | Knee-extension lever arc, fixed thighs and pelvis; separate machine geometry. |
| Seated Leg Curl Machine | Knee-flexion arc distinct from extension; thigh restraint remains fixed. |
| Standing Machine Calf Raise | Forefoot contact fixed; heels and supported body rise; pads move with shoulders. |

Other variations remain explicitly unavailable and do not inherit one of these guides. Stable catalog IDs can replace name matching when a reviewed asset registry is introduced; renaming a variant currently fails closed.

## Validation actually performed

- `dart analyze lib test`: no issues.
- Full `flutter test --no-pub`: **42 tests passed**. These include existing mocked authentication tests, not live backend verification.
- Six focused avatar tests: placeholder GLB inspection, unavailable seed mappings, all 15 exact variants at 360px and 430px width (430px with 1.4x text), retry after failed load, unknown ID behavior, and no cross-variant guide substitution.
- Captured and visually inspected all 15 fallback-guide previews at 360px screen width. They are previews of the unavailable UI, not exercise-motion evidence.
- Mobile widget tests reported no layout/paint exceptions. They also checked zero transient animation callbacks after settling; this viewer has no animation controller.
- Release web build succeeded in **35.4 seconds**; Wasm dry run succeeded. Build time is not a runtime-performance measurement.
- No real-device FPS, GPU-memory, thermal, battery or load-latency benchmark was performed.
- No start/mid/end/return/full-loop or multi-camera biomechanics review was possible: there are no approved animations to inspect. Android/iOS builds and hardware tests were not performed in this pass.

## Exact missing implementation and assets

1. A licensed or original character mesh with readable anatomy, UV/material data, a documented skeleton, skin weights and tested shoulder/hip/wrist deformation. Include named muscle regions for qualitative overlays.
2. Fifteen exercise-specific clips on that skeleton, separated by equipment/stance variation. Include rest pose, clip timing, handedness, root-motion policy and contact markers. Do not substitute motions based on broad categories.
3. Scaled equipment models: barbells/plates/collars, dumbbells, relevant kettlebells, benches/racks/safeties/platforms, fixed pull-up structure, cable tower/pulleys/attachments/stacks, 45-degree sled press, knee-extension machine, each intended curl machine, calf machine.
4. Machine pivots, cable paths/ratios, moving resistance parts, hand/foot contact anchors, seat supports and collision boundaries; consistent world units.
5. A Flutter-compatible renderer integrated on the intended platforms. Loading a GLB or toggling a JSON flag alone must not enable a demonstration. The new catalog deliberately rejects a claimed available renderer.
6. Real playback, slow motion, scrub, front/side/three-quarter and free camera controls, camera reset, labels and muscle overlay tied to the actual rendered scene.
7. Lazy GPU/asset loading, explicit byte-budgeted eviction, lifecycle/visibility pausing, resource disposal, reduced-motion behavior and simpler model variants for slow devices.
8. Qualified movement review across body proportions and camera angles, documenting start, midpoint, end, return and full loop for every clip. Reference text and code tests cannot replace this review.
9. License/provenance records permitting app distribution for every new asset. No purchase or publication has been performed.

## Written references

These references support only the short written cues shown in six cards. No source certifies the app's former animation.

- [NASM: Barbell Bench Press](https://www.nasm.org/resource-center/exercise-library/barbell-bench-press)
- [NASM: Conventional Barbell Deadlift](https://www.nasm.org/resource-center/exercise-library/barbell-deadlift)
- [NASM: Romanian Deadlift (RDL)](https://www.nasm.org/resource-center/exercise-library/romanian-deadlift-barbell)
- [NASM: Strict Bodyweight Pull-Ups](https://www.nasm.org/resource-center/exercise-library/pull-up)
- [NASM: 45-Degree Sled Leg Press](https://www.nasm.org/resource-center/exercise-library/leg-press)
- [NASM: Seated Leg Curl Machine](https://www.nasm.org/resource-center/exercise-library/seated-leg-curl)

## Changed project files

- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/widgets/exercise_3d_viewer.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/models/exercise_demonstration.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/models/exercise.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/data/exercise_seed_data.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/screens/exercises_screen.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/screens/workouts_screen.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/screens/dashboard_screen.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/lib/screens/rankings_screen.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/assets/data/exercise_demonstrations.json`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/pubspec.yaml`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/test/anatomy_viewer_preview_test.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/test/widget_test.dart`
- `C:/Users/Reatanak/OneDrive/Desktop/i4/codeflutter/tp1/docs/exercise-avatar-audit.md`
