import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../storage/cloud_storage_service.dart';

/// Stable Exercise Video Asset Descriptor for AI Agent 2's animation/video player.
class ExerciseVideoAssetDescriptor {
  final String mediaAssetId;
  final String exerciseId;
  final String videoId;
  final String storageObjectPath; // exercise-videos/{exercise_id}/{video_id}.mp4
  final SignedMediaUrl signedMediaUrl;
  final List<double> supportedPlaybackSpeeds;
  final bool loopByDefault;
  final String licenseSource;
  final bool allowRawDownload;

  const ExerciseVideoAssetDescriptor({
    required this.mediaAssetId,
    required this.exerciseId,
    required this.videoId,
    required this.storageObjectPath,
    required this.signedMediaUrl,
    this.supportedPlaybackSpeeds = const [0.5, 1.0, 1.5],
    this.loopByDefault = true,
    this.licenseSource = 'https://gym-animations.com/',
    this.allowRawDownload = false,
  });
}

/// Stable 3D Anatomical GLB Model Asset Descriptor for AI Agent 2's 3D Avatar Renderer.
class AnatomyModelAssetDescriptor {
  final String mediaAssetId;
  final String modelId;
  final String version;
  final String storageObjectPath; // anatomy-models/{model_id}/{version}.glb
  final String localFallbackAssetPath;
  final SignedMediaUrl signedMediaUrl;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String primaryHighlightHex; // #39FF14
  final String secondaryHighlightHex; // #9DDF91
  final String neutralGrayscaleHex; // #6B7280

  const AnatomyModelAssetDescriptor({
    required this.mediaAssetId,
    required this.modelId,
    required this.version,
    required this.storageObjectPath,
    required this.localFallbackAssetPath,
    required this.signedMediaUrl,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    this.primaryHighlightHex = '#39FF14',
    this.secondaryHighlightHex = '#9DDF91',
    this.neutralGrayscaleHex = '#6B7280',
  });
}

/// Stable 3D Gym Equipment & Machine GLB Asset Descriptor for AI Agent 2.
class EquipmentAndMachineAssetDescriptor {
  final String mediaAssetId;
  final String exerciseId;
  final String equipmentId;
  final String? machineId;
  final String version;
  final String equipmentObjectPath; // exercise-equipment/{equipment_id}/{version}.glb
  final String? machineObjectPath; // machine-models/{machine_id}/{version}.glb
  final SignedMediaUrl equipmentSignedUrl;
  final SignedMediaUrl? machineSignedUrl;

  const EquipmentAndMachineAssetDescriptor({
    required this.mediaAssetId,
    required this.exerciseId,
    required this.equipmentId,
    this.machineId,
    required this.version,
    required this.equipmentObjectPath,
    this.machineObjectPath,
    required this.equipmentSignedUrl,
    this.machineSignedUrl,
  });
}

/// Receipt returned when saving workout data via AI Agent 1's persistence layer.
class WorkoutSaveReceipt {
  final bool isSuccess;
  final String workoutId;
  final String userId;
  final String idempotencyKey;
  final int unlockedPrCount;
  final String statusMessage;
  final DateTime savedAt;

  const WorkoutSaveReceipt({
    required this.isSuccess,
    required this.workoutId,
    required this.userId,
    required this.idempotencyKey,
    required this.unlockedPrCount,
    required this.statusMessage,
    required this.savedAt,
  });
}

/// Official Backend Integration Contract provided by AI Agent 1 for AI Agent 2.
/// AI Agent 2 (3D Avatar, Gym Equipment, Exercise Animations & Fitness UI) consumes
/// this interface without needing direct knowledge of RLS, Keychain tokens, or storage signing.
abstract class Agent2ExerciseAnd3DContract {
  /// 1. Fetching exercises with stable exercise IDs
  Future<List<Exercise>> fetchExercises({
    String? category,
    String? equipment,
    String? searchQuery,
  });

  Future<Exercise?> fetchExerciseById(String exerciseId);

  /// 2. Fetching exercise video assets (`exercise-videos/{exercise_id}/{video_id}.mp4`)
  Future<ExerciseVideoAssetDescriptor> fetchExerciseVideoAsset({
    required String exerciseId,
    String? videoId,
  });

  /// 3. Fetching anatomical 3D model assets (`anatomy-models/{model_id}/{version}.glb`)
  Future<AnatomyModelAssetDescriptor> fetchAnatomyModelAsset({
    required String exerciseId,
    String modelId = 'lifting_life_anatomy',
    String version = 'v1',
  });

  /// 4. Fetching equipment and machine 3D model assets
  /// (`exercise-equipment/{equipment_id}/{version}.glb` & `machine-models/{machine_id}/{version}.glb`)
  Future<EquipmentAndMachineAssetDescriptor> fetchEquipmentAndMachineAssets({
    required String exerciseId,
    String version = 'v1',
  });

  /// 5. Saving workout data (idempotent, persists to local encrypted storage & Supabase)
  Future<WorkoutSaveReceipt> saveWorkoutData({
    required Workout workout,
    String? clientIdempotencyKey,
  });

  Future<void> saveActiveWorkoutDraft(Workout? draft);

  /// 6. Reading workout history & personal records for the authenticated user
  Future<List<Workout>> fetchWorkoutHistory({int limit = 50});

  Future<List<PersonalRecord>> fetchPersonalRecords({String? exerciseId});

  /// Maps a human-readable equipment name to a stable `equipment_id`.
  static String resolveStableEquipmentId(String equipmentName) {
    switch (equipmentName.trim().toLowerCase()) {
      case 'barbell':
        return 'eq_olympic_barbell';
      case 'dumbbell':
        return 'eq_hex_dumbbell_pair';
      case 'cable':
        return 'eq_dual_adjustable_pulley';
      case 'machine':
        return 'eq_selectorized_station';
      case 'bodyweight':
        return 'eq_bodyweight_rig';
      case 'resistance band':
        return 'eq_resistance_band';
      default:
        return 'eq_${equipmentName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    }
  }

  /// Maps an exercise category + equipment to a stable `machine_id` when applicable.
  static String? resolveStableMachineId(Exercise exercise) {
    final eq = exercise.equipment.trim().toLowerCase();
    if (eq != 'machine' && eq != 'cable') return null;
    return 'mach_${exercise.movementPattern.toLowerCase()}_station';
  }
}

