import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// An exact exercise variant, never an animation inferred from a broad pattern.
/// All current entries are unavailable. Asset presence alone cannot approve a demo.
class ExerciseDemonstration {
  final String exerciseName;
  final String equipment;
  final List<String> equipmentParts;
  final String setup;
  final String cue;
  final String? reference;

  const ExerciseDemonstration({
    required this.exerciseName,
    required this.equipment,
    required this.equipmentParts,
    required this.setup,
    required this.cue,
    this.reference,
  });

  factory ExerciseDemonstration.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'available' && json['status'] != 'unavailable') {
      throw const FormatException('Invalid demonstration status');
    }
    return ExerciseDemonstration(
      exerciseName: json['exerciseName'] as String,
      equipment: json['equipment'] as String,
      equipmentParts: List<String>.unmodifiable(json['equipmentParts'] as List),
      setup: json['setup'] as String,
      cue: json['cue'] as String,
      reference: json['reference'] as String?,
    );
  }
}

/// Caches only the small text catalog, not GLB buffers or rendered surfaces.
/// Failures can be retried; no failing future is permanently cached.
class ExerciseDemonstrationCatalog {
  static Future<List<ExerciseDemonstration>>? _cached;
  static List<ExerciseDemonstration>? _entries;

  static Future<List<ExerciseDemonstration>> load({AssetBundle? bundle}) {
    if (bundle != null) return _read(bundle);
    if (_entries != null) return Future.value(_entries);
    return _cached ??= _read(rootBundle)
        .then((entries) {
          _entries = entries;
          _cached = null;
          return entries;
        })
        .catchError((Object error) {
          _cached = null;
          throw error;
        });
  }

  static Future<List<ExerciseDemonstration>> _read(AssetBundle bundle) async {
    final raw = await bundle
        .loadString('assets/data/exercise_demonstrations.json', cache: false)
        .timeout(const Duration(seconds: 8));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported demonstration catalog');
    }
    final entries = (json['entries'] as List)
        .map((e) => ExerciseDemonstration.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final names = entries.map((e) => e.exerciseName).toSet();
    if (names.length != entries.length || entries.length > 100) {
      throw const FormatException('Invalid demonstration catalog');
    }
    return List.unmodifiable(entries);
  }
}
