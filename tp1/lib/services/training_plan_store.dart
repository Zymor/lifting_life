import '../core/security/secure_session_storage.dart';
import '../models/workout.dart';

class TrainingPlanStore {
  final String userId;
  TrainingPlanStore(this.userId);
  final Map<int, Workout> weekly = {};
  final Map<String, Workout?> overrides = {};
  final List<Workout> rotation = [];
  final Map<String, double> weighIns = {};
  int rotationIndex = 0;
  bool useRotation = false;
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Workout? forDate(DateTime date) {
    final key = dayKey(date);
    if (overrides.containsKey(key)) return overrides[key];
    if (useRotation) {
      return rotation.isEmpty
          ? null
          : rotation[rotationIndex % rotation.length];
    }
    return weekly[date.weekday];
  }

  Future<void> load() async {
    final raw = await SecureSessionStorage.instance.readUserScopedJson(
      userId: userId,
      collection: 'training_plan_v1',
    );
    if (raw is! Map) return;
    weekly.clear();
    overrides.clear();
    rotation.clear();
    weighIns.clear();
    for (final entry in (raw['weekly'] as Map? ?? {}).entries) {
      weekly[int.parse(entry.key as String)] = Workout.fromMap(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    for (final entry in (raw['overrides'] as Map? ?? {}).entries) {
      overrides[entry.key as String] = entry.value == null
          ? null
          : Workout.fromMap(Map<String, dynamic>.from(entry.value as Map));
    }
    for (final item in (raw['rotation'] as List? ?? [])) {
      rotation.add(Workout.fromMap(Map<String, dynamic>.from(item as Map)));
    }
    for (final entry in (raw['weighIns'] as Map? ?? {}).entries) {
      weighIns[entry.key as String] = (entry.value as num).toDouble();
    }
    rotationIndex = (raw['rotationIndex'] as int? ?? 0).clamp(0, 1000000);
    useRotation = raw['useRotation'] == true;
  }

  Future<void> save() => SecureSessionStorage.instance.saveUserScopedJson(
    userId: userId,
    collection: 'training_plan_v1',
    jsonEncodable: {
      'version': 1,
      'weekly': weekly.map((key, value) => MapEntry('$key', value.toMap())),
      'overrides': overrides.map((key, value) => MapEntry(key, value?.toMap())),
      'rotation': rotation.map((e) => e.toMap()).toList(),
      'rotationIndex': rotationIndex,
      'useRotation': useRotation,
      'weighIns': weighIns,
    },
  );
  void recordWeight(DateTime date, double kg) {
    if (!kg.isFinite || kg <= 0 || kg > 1000) {
      throw ArgumentError('Invalid weight');
    }
    weighIns[dayKey(date)] = kg;
  }
}
