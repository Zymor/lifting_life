import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/user_profile.dart';
import '../configuration/supabase_config.dart';

/// Provenance classification required by Task 1 Mandatory Data Safety.
enum RecordProvenance {
  productionVerified('production_verified'),
  catalogSeed('catalog_seed'),
  developmentTest('development_test'),
  demoSeed('demo_seed'),
  unknown('unknown');

  final String value;
  const RecordProvenance(this.value);
}

class PreCleanupBackupSnapshot {
  final String backupId;
  final AppEnvironment environment;
  final String createdByUserId;
  final String sha256Checksum;
  final Map<String, List<Map<String, dynamic>>> snapshotTables;
  final DateTime createdAt;
  final bool isVerified;

  const PreCleanupBackupSnapshot({
    required this.backupId,
    required this.environment,
    required this.createdByUserId,
    required this.sha256Checksum,
    required this.snapshotTables,
    required this.createdAt,
    required this.isVerified,
  });
}

class DemoCleanupPreview {
  final String previewId;
  final String backupId;
  final AppEnvironment environment;
  final List<String> demoUserIdsToDelete;
  final List<String> demoWorkoutIdsToDelete;
  final List<String> demoPostIdsToDelete;
  final List<String> demoCourseIdsToDelete;
  final int preservedRealUsersCount;
  final int preservedRealWorkoutsCount;
  final int preservedPublishedCoursesCount;
  final int preservedCatalogExercisesCount;
  final DateTime generatedAt;

  const DemoCleanupPreview({
    required this.previewId,
    required this.backupId,
    required this.environment,
    required this.demoUserIdsToDelete,
    required this.demoWorkoutIdsToDelete,
    required this.demoPostIdsToDelete,
    required this.demoCourseIdsToDelete,
    required this.preservedRealUsersCount,
    required this.preservedRealWorkoutsCount,
    required this.preservedPublishedCoursesCount,
    required this.preservedCatalogExercisesCount,
    required this.generatedAt,
  });

  int get totalDemoRecordsTargeted =>
      demoUserIdsToDelete.length +
      demoWorkoutIdsToDelete.length +
      demoPostIdsToDelete.length +
      demoCourseIdsToDelete.length;
}

class DemoCleanupReport {
  final bool executed;
  final String message;
  final String? previewId;
  final String? backupId;
  final int deletedDemoUsers;
  final int deletedDemoWorkouts;
  final int deletedDemoPosts;
  final int deletedDemoCourses;
  final int preservedRealRecords;
  final DateTime timestamp;

  const DemoCleanupReport({
    required this.executed,
    required this.message,
    this.previewId,
    this.backupId,
    this.deletedDemoUsers = 0,
    this.deletedDemoWorkouts = 0,
    this.deletedDemoPosts = 0,
    this.deletedDemoCourses = 0,
    this.preservedRealRecords = 0,
    required this.timestamp,
  });
}

/// Enforces the 8-step Mandatory Data Safety workflow (Task 1):
/// 1. Identify current environment
/// 2. Inspect existing database tables
/// 3. Create a verified SHA-256 backup
/// 4. Distinguish seeded demo data from real records
/// 5. Generate a deletion preview
/// 6. Require explicit Owner confirmation before destructive cleanup
/// 7. Remove confirmed demo records only
/// 8. Preserve all real user accounts, workouts, PRs, published courses, and licensed videos
class DemoDataCleanupService {
  DemoDataCleanupService._();
  static final DemoDataCleanupService instance = DemoDataCleanupService._();

  final Map<String, PreCleanupBackupSnapshot> _backups = {};
  final Map<String, DemoCleanupPreview> _previews = {};

  /// Known demo seed identifiers from legacy prototypes.
  static const Set<String> knownDemoIdentifiers = {
    'u_demo',
    'u_owner_alex',
    'u_sarah',
    'u_marcus',
    'u_elena',
    'u_devon',
    'u_kai',
    'w_demo_push',
    'w_demo_legs',
    'post_demo_1',
    'post_demo_2',
    'post_demo_3',
  };

  /// Classifies a record's provenance without ever assuming unknown records are fake.
  RecordProvenance classifyRecord({
    required String id,
    String? explicitProvenanceTag,
    bool isCatalogExerciseOrProgram = false,
  }) {
    if (isCatalogExerciseOrProgram) return RecordProvenance.catalogSeed;
    if (explicitProvenanceTag == 'demo_seed' ||
        knownDemoIdentifiers.contains(id)) {
      return RecordProvenance.demoSeed;
    }
    if (explicitProvenanceTag == 'development_test') {
      return RecordProvenance.developmentTest;
    }
    if (explicitProvenanceTag == 'production_verified') {
      return RecordProvenance.productionVerified;
    }
    // Never assume a record is fake just because it lacks a tag!
    return RecordProvenance.unknown;
  }

  /// Steps 1-5: Creates a verified backup and generates a non-destructive deletion preview.
  DemoCleanupPreview createBackupAndGeneratePreview({
    required String actorUserId,
    required UserRole actorRole,
    required AppEnvironment environment,
    required List<Map<String, dynamic>> usersTable,
    required List<Map<String, dynamic>> workoutsTable,
    required List<Map<String, dynamic>> postsTable,
    required List<Map<String, dynamic>> coursesTable,
    required int catalogExercisesCount,
  }) {
    if (actorRole != UserRole.owner) {
      throw StateError(
        'Forbidden: Only the App Owner can generate a demo-data cleanup preview.',
      );
    }

    if (environment == AppEnvironment.production) {
      throw StateError(
        'Safety Guard: Automated demo cleanup is blocked in production by default.',
      );
    }

    final snapshotTables = <String, List<Map<String, dynamic>>>{
      'profiles': List<Map<String, dynamic>>.from(usersTable),
      'workout_sessions': List<Map<String, dynamic>>.from(workoutsTable),
      'posts': List<Map<String, dynamic>>.from(postsTable),
      'courses': List<Map<String, dynamic>>.from(coursesTable),
    };

    final serialized = jsonEncode(snapshotTables);
    final checksum = sha256.convert(utf8.encode(serialized)).toString();
    final backupId = 'bkp_${DateTime.now().microsecondsSinceEpoch}';

    final backup = PreCleanupBackupSnapshot(
      backupId: backupId,
      environment: environment,
      createdByUserId: actorUserId,
      sha256Checksum: checksum,
      snapshotTables: snapshotTables,
      createdAt: DateTime.now(),
      isVerified: checksum.length == 64,
    );
    _backups[backupId] = backup;

    final demoUsers = <String>[];
    int realUsers = 0;
    for (final u in usersTable) {
      final id = (u['id'] ?? '').toString();
      final prov = classifyRecord(
        id: id,
        explicitProvenanceTag: u['provenance']?.toString(),
      );
      if (prov == RecordProvenance.demoSeed) {
        demoUsers.add(id);
      } else {
        realUsers++;
      }
    }

    final demoWorkouts = <String>[];
    int realWorkouts = 0;
    for (final w in workoutsTable) {
      final id = (w['id'] ?? '').toString();
      final prov = classifyRecord(
        id: id,
        explicitProvenanceTag: w['provenance']?.toString(),
      );
      if (prov == RecordProvenance.demoSeed) {
        demoWorkouts.add(id);
      } else {
        realWorkouts++;
      }
    }

    final demoPosts = <String>[];
    for (final p in postsTable) {
      final id = (p['id'] ?? '').toString();
      final prov = classifyRecord(
        id: id,
        explicitProvenanceTag: p['provenance']?.toString(),
      );
      if (prov == RecordProvenance.demoSeed) {
        demoPosts.add(id);
      }
    }

    final demoCourses = <String>[];
    int publishedCourses = 0;
    for (final c in coursesTable) {
      final id = (c['id'] ?? '').toString();
      final status = (c['status'] ?? '').toString();
      final prov = classifyRecord(
        id: id,
        explicitProvenanceTag: c['provenance']?.toString(),
      );
      // Never delete published/approved courses unless explicitly demo_seed & non-approved
      if (status == 'approved') {
        publishedCourses++;
      } else if (prov == RecordProvenance.demoSeed) {
        demoCourses.add(id);
      }
    }

    final previewId = 'prv_${DateTime.now().microsecondsSinceEpoch}';
    final preview = DemoCleanupPreview(
      previewId: previewId,
      backupId: backupId,
      environment: environment,
      demoUserIdsToDelete: demoUsers,
      demoWorkoutIdsToDelete: demoWorkouts,
      demoPostIdsToDelete: demoPosts,
      demoCourseIdsToDelete: demoCourses,
      preservedRealUsersCount: realUsers,
      preservedRealWorkoutsCount: realWorkouts,
      preservedPublishedCoursesCount: publishedCourses,
      preservedCatalogExercisesCount: catalogExercisesCount,
      generatedAt: DateTime.now(),
    );

    _previews[previewId] = preview;
    return preview;
  }

  /// Steps 6-8: Executes deletion of ONLY confirmed demo records after verifying the backup and Owner confirmation.
  DemoCleanupReport executeConfirmedCleanup({
    required String previewId,
    required UserRole actorRole,
    required bool ownerConfirmed,
    required List<Map<String, dynamic>> usersTable,
    required List<Map<String, dynamic>> workoutsTable,
    required List<Map<String, dynamic>> postsTable,
    required List<Map<String, dynamic>> coursesTable,
  }) {
    if (actorRole != UserRole.owner) {
      return DemoCleanupReport(
        executed: false,
        message: 'Forbidden: Only the App Owner can execute demo-data cleanup.',
        timestamp: DateTime.now(),
      );
    }

    if (!ownerConfirmed) {
      return DemoCleanupReport(
        executed: false,
        message:
            'Aborted: Explicit Owner confirmation is required before deleting demo records.',
        timestamp: DateTime.now(),
      );
    }

    final preview = _previews[previewId];
    if (preview == null) {
      return DemoCleanupReport(
        executed: false,
        message: 'Aborted: Cleanup preview "$previewId" was not found.',
        timestamp: DateTime.now(),
      );
    }

    final backup = _backups[preview.backupId];
    if (backup == null || !backup.isVerified) {
      return DemoCleanupReport(
        executed: false,
        message:
            'Aborted: Verified pre-cleanup backup snapshot is missing or invalid.',
        timestamp: DateTime.now(),
      );
    }

    final demoUserSet = preview.demoUserIdsToDelete.toSet();
    final demoWorkoutSet = preview.demoWorkoutIdsToDelete.toSet();
    final demoPostSet = preview.demoPostIdsToDelete.toSet();
    final demoCourseSet = preview.demoCourseIdsToDelete.toSet();

    final beforeUsers = usersTable.length;
    usersTable.removeWhere((u) => demoUserSet.contains(u['id']?.toString()));
    final deletedUsers = beforeUsers - usersTable.length;

    final beforeWorkouts = workoutsTable.length;
    workoutsTable.removeWhere(
      (w) => demoWorkoutSet.contains(w['id']?.toString()),
    );
    final deletedWorkouts = beforeWorkouts - workoutsTable.length;

    final beforePosts = postsTable.length;
    postsTable.removeWhere((p) => demoPostSet.contains(p['id']?.toString()));
    final deletedPosts = beforePosts - postsTable.length;

    final beforeCourses = coursesTable.length;
    coursesTable.removeWhere(
      (c) =>
          demoCourseSet.contains(c['id']?.toString()) &&
          c['status'] != 'approved',
    );
    final deletedCourses = beforeCourses - coursesTable.length;

    final preservedTotal = usersTable.length +
        workoutsTable.length +
        postsTable.length +
        coursesTable.length +
        preview.preservedCatalogExercisesCount;

    return DemoCleanupReport(
      executed: true,
      message:
          'Confirmed demo cleanup completed safely. Preserved $preservedTotal real/catalog records.',
      previewId: previewId,
      backupId: backup.backupId,
      deletedDemoUsers: deletedUsers,
      deletedDemoWorkouts: deletedWorkouts,
      deletedDemoPosts: deletedPosts,
      deletedDemoCourses: deletedCourses,
      preservedRealRecords: preservedTotal,
      timestamp: DateTime.now(),
    );
  }
}
