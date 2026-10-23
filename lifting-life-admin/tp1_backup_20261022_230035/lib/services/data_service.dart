import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/auth/email_otp_auth_service.dart';
import '../core/configuration/supabase_config.dart';
import '../core/contracts/agent2_exercise_3d_contract.dart';
import '../core/security/secure_session_storage.dart';
import '../core/storage/cloud_storage_service.dart';
import '../data/exercise_seed_data.dart';
import '../models/course.dart';
import '../models/exercise.dart';
import '../models/goal.dart';
import '../models/nutrition.dart';
import '../models/program.dart';
import '../models/social.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

class OtpVerificationResult {
  final bool isSuccess;
  final String message;
  final bool isExpired;
  final bool isRateLimited;

  const OtpVerificationResult({
    required this.isSuccess,
    required this.message,
    this.isExpired = false,
    this.isRateLimited = false,
  });
}

class AuthActionResult {
  final bool isSuccess;
  final String message;
  final bool requiresEmailVerification;

  const AuthActionResult({
    required this.isSuccess,
    required this.message,
    this.requiresEmailVerification = false,
  });
}

/// Local cache of a signed-in account's profile. Credentials and OTPs are
/// never stored here — Supabase Auth owns passwords, codes, and sessions.
class _StoredUserAccount {
  final String userId;
  final String email;
  final String username;
  final UserProfile profile;
  final String? passwordSalt;
  final String? passwordHash;
  final bool hasCompletedOnboarding;

  const _StoredUserAccount({
    required this.userId,
    required this.email,
    required this.username,
    required this.profile,
    this.passwordSalt,
    this.passwordHash,
    this.hasCompletedOnboarding = false,
  });

  _StoredUserAccount copyWith({
    String? email,
    String? username,
    UserProfile? profile,
    String? passwordSalt,
    String? passwordHash,
    bool? hasCompletedOnboarding,
  }) {
    return _StoredUserAccount(
      userId: userId,
      email: email ?? this.email,
      username: username ?? this.username,
      profile: profile ?? this.profile,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      passwordHash: passwordHash ?? this.passwordHash,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

class DataService extends ChangeNotifier
    implements Agent2ExerciseAnd3DContract {
  DataService._internal() {
    initializeProductionState();
  }
  static final DataService instance = DataService._internal();

  final Random _random = Random.secure();

  String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String _generateSalt() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _hashWithSalt(String value, String salt) {
    const mask = 0xffffffff;
    const initial = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];
    const constants = <int>[
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];

    int rotateRight(int x, int n) => ((x >> n) | (x << (32 - n))) & mask;

    // `utf8.encode` returns a fixed-length Uint8List on current Dart SDKs;
    // copying it into a growable list is required by the padding below.
    // (This was the crash behind the CREATE ACCOUNT button doing nothing.)
    final bytes = List<int>.of(utf8.encode('$salt:$value'));
    final bitLength = bytes.length * 8;
    bytes.add(0x80);
    while (bytes.length % 64 != 56) {
      bytes.add(0);
    }
    for (var shift = 56; shift >= 0; shift -= 8) {
      bytes.add((bitLength >> shift) & 0xff);
    }

    final hash = List<int>.from(initial);
    for (var offset = 0; offset < bytes.length; offset += 64) {
      final words = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i++) {
        final j = offset + i * 4;
        words[i] =
            (bytes[j] << 24) |
            (bytes[j + 1] << 16) |
            (bytes[j + 2] << 8) |
            bytes[j + 3];
      }
      for (var i = 16; i < 64; i++) {
        final x = words[i - 15];
        final y = words[i - 2];
        final s0 = rotateRight(x, 7) ^ rotateRight(x, 18) ^ (x >> 3);
        final s1 = rotateRight(y, 17) ^ rotateRight(y, 19) ^ (y >> 10);
        words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & mask;
      }

      var a = hash[0];
      var b = hash[1];
      var c = hash[2];
      var d = hash[3];
      var e = hash[4];
      var f = hash[5];
      var g = hash[6];
      var h = hash[7];
      for (var i = 0; i < 64; i++) {
        final sum1 =
            rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
        final choose = (e & f) ^ ((~e) & g);
        final temp1 = (h + sum1 + choose + constants[i] + words[i]) & mask;
        final sum0 =
            rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
        final majority = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (sum0 + majority) & mask;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & mask;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & mask;
      }
      hash[0] = (hash[0] + a) & mask;
      hash[1] = (hash[1] + b) & mask;
      hash[2] = (hash[2] + c) & mask;
      hash[3] = (hash[3] + d) & mask;
      hash[4] = (hash[4] + e) & mask;
      hash[5] = (hash[5] + f) & mask;
      hash[6] = (hash[6] + g) & mask;
      hash[7] = (hash[7] + h) & mask;
    }
    return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
  }

  // ============================================================================
  // EMAIL AUTH BACKEND (Supabase Auth in production; injectable for tests)
  // ============================================================================
  EmailOtpAuthBackend? _emailAuthOverride;
  SupabaseEmailOtpBackend? _supabaseEmailAuth;

  EmailOtpAuthBackend get emailAuthBackend {
    final override = _emailAuthOverride;
    if (override != null) return override;
    final client = SupabaseConfig.clientOrNull;
    if (client != null) {
      return _supabaseEmailAuth ??= SupabaseEmailOtpBackend(client);
    }
    return const UnconfiguredEmailOtpBackend();
  }

  /// Injects a backend (used by automated tests only).
  @visibleForTesting
  void useEmailAuthBackendForTesting(EmailOtpAuthBackend? backend) {
    _emailAuthOverride = backend;
  }

  bool _isAuthenticated = false;
  bool _hasCompletedOnboarding = false;
  bool _rememberSession = true;
  bool _isDemo = false;
  String? _lastAuthError;

  bool get rememberSession => _rememberSession;
  String? get lastAuthError => _lastAuthError;

  // User-isolated backend stores (keyed by userId / lowercased email)
  final Map<String, _StoredUserAccount> _accountsByEmail = {};
  final Map<String, List<Workout>> _workoutsByUser = {};
  final Map<String, List<PersonalRecord>> _prsByUser = {};
  final Map<String, Workout?> _draftByUser = {};
  final Map<String, Set<String>> _enrolledCourseIdsByUser = {};
  final Map<String, Map<String, Set<String>>> _completedLessonsByUser = {};

  UserProfile? _currentUser;
  final List<Exercise> _exercises = [];
  final Set<String> _favoriteExerciseIds = {};

  final List<Workout> _workouts = [];
  final List<Workout> _workoutTemplates = [];
  Workout? _activeWorkoutDraft; // Preserved active workout across app restarts

  final List<PersonalRecord> _personalRecords = [];
  final List<TrainingProgram> _programs = [];
  final List<SocialPost> _socialPosts = [];
  final List<LeaderboardEntry> _leaderboardEntries = [];
  final List<FitnessChallenge> _challenges = [];
  final List<FitnessCourse> _courses = [];
  final List<AppNotification> _notifications = [];
  final List<AbuseReport> _reports = [];
  final List<AdminAuditLog> _auditLogs = [];

  final List<MealEntry> _meals = [];
  final List<Goal> _goals = [];
  NutritionTargets _nutritionTargets = const NutritionTargets();
  final List<FoodItem> _customFoods = [];

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isDemo => _isDemo;
  UserProfile? get currentUser => _currentUser;
  List<Exercise> get exercises => List.unmodifiable(_exercises);
  Set<String> get favoriteExerciseIds => Set.unmodifiable(_favoriteExerciseIds);
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<Workout> get workoutTemplates => List.unmodifiable(_workoutTemplates);
  Workout? get activeWorkoutDraft => _activeWorkoutDraft;
  List<PersonalRecord> get personalRecords =>
      List.unmodifiable(_personalRecords);
  List<TrainingProgram> get programs => List.unmodifiable(_programs);
  List<SocialPost> get socialPosts => List.unmodifiable(
    _socialPosts.where(
      (p) => !(_currentUser?.blockedUserIds.contains(p.authorId) ?? false),
    ),
  );
  List<LeaderboardEntry> get leaderboardEntries =>
      List.unmodifiable(_leaderboardEntries);
  List<FitnessChallenge> get challenges => List.unmodifiable(_challenges);
  List<FitnessCourse> get courses => List.unmodifiable(_courses);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AbuseReport> get reports => List.unmodifiable(_reports);
  List<AdminAuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  List<MealEntry> get meals => List.unmodifiable(_meals);
  List<Goal> get goals => List.unmodifiable(_goals);
  NutritionTargets get nutritionTargets => _nutritionTargets;
  List<FoodItem> get foodLibrary =>
      List.unmodifiable([...VerifiedFoodCatalog.verifiedStaples, ..._customFoods]);

  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;

  int get pendingCoursesCount =>
      _courses.where((c) => c.status == CourseStatus.pendingReview).length;

  /// Computed Powerlifting SBD Total (Squat + Bench + Deadlift best e1RM in kg) for the active user.
  double get currentUserSbdTotalKg {
    double bestSquat = 0;
    double bestBench = 0;
    double bestDeadlift = 0;
    for (final pr in _personalRecords) {
      if (pr.category == 'Squat' && pr.estimated1RM > bestSquat) {
        bestSquat = pr.estimated1RM;
      } else if (pr.category == 'Bench Press' && pr.estimated1RM > bestBench) {
        bestBench = pr.estimated1RM;
      } else if (pr.category == 'Deadlift' && pr.estimated1RM > bestDeadlift) {
        bestDeadlift = pr.estimated1RM;
      }
    }
    return bestSquat + bestBench + bestDeadlift;
  }

  /// Dynamic leaderboard rank for the active user, or null when unranked / no leaderboard entries.
  int? get currentUserLeaderboardRank {
    if (_currentUser == null || _leaderboardEntries.isEmpty) return null;
    final idx = _leaderboardEntries.indexWhere(
      (e) => e.userId == _currentUser!.id,
    );
    if (idx == -1) return null;
    return idx + 1;
  }

  /// Initializes the clean production state with master reference catalogs
  /// (Exercises, Programs, Official Courses) and zero fake user/workout/social records.
  void initializeProductionState() {
    _isAuthenticated = false;
    _hasCompletedOnboarding = false;
    _isDemo = false;
    _lastAuthError = null;
    _currentUser = null;
    _activeWorkoutDraft = null;

    _accountsByEmail.clear();
    _workoutsByUser.clear();
    _prsByUser.clear();
    _draftByUser.clear();
    _enrolledCourseIdsByUser.clear();
    _completedLessonsByUser.clear();
    SecureSessionStorage.instance.clearMemoryVaultForTesting();

    _workouts.clear();
    _personalRecords.clear();
    _socialPosts.clear();
    _leaderboardEntries.clear();
    _challenges.clear();
    _notifications.clear();
    _reports.clear();
    _auditLogs.clear();
    _meals.clear();
    _goals.clear();

    if (isDevelopmentDemoAvailable) {
      _addDevelopmentDemoAccount();
    }
    _favoriteExerciseIds.clear();

    if (_exercises.isEmpty) {
      _exercises.addAll(ExerciseSeedData.build200PlusExercises());
    }
    if (_programs.isEmpty) {
      _seedTrainingPrograms();
    }
    _workoutTemplates
      ..clear()
      ..addAll(_buildStandardTemplates());
    _courses
      ..clear()
      ..addAll(_buildOfficialApprovedCatalogCourses());
  }

  static const String devDemoEmail = 'dev@liftinglife.app';
  static const String devDemoPassword = 'DevPassword123!';
  static const String legacyDemoEmail = 'demo.lifter.4821@example.com';
  static const String legacyDemoPassword = 'V9!qR7#zL2@mK8';

  bool get isDevelopmentDemoAvailable =>
      kDebugMode &&
      SupabaseConfig.environment == AppEnvironment.development &&
      SupabaseConfig.supabaseUrl.isEmpty &&
      SupabaseConfig.clientKey.isEmpty &&
      !emailAuthBackend.isConfigured &&
      const bool.fromEnvironment('ENABLE_DEMO_ACCOUNT', defaultValue: true);

  void _addDevelopmentDemoAccount() {
    if (!isDevelopmentDemoAvailable) return;

    // 1. Primary Developer Test Account (admin role, full access to test all features)
    final devProfile = UserProfile(
      id: 'dev_test_user_001',
      email: devDemoEmail,
      emailVerified: true,
      username: 'dev_tester',
      name: 'Developer Tester',
      experienceLevel: 'Advanced',
      trainingInterest: 'Hybrid Training',
      linkedProviders: const ['email'],
      role: UserRole.admin,
      isPremium: true,
      xpPoints: 2450,
      streakDays: 12,
      createdAt: DateTime(2026, 1, 1),
    );
    final devSalt = _generateSalt();
    _accountsByEmail[devDemoEmail] = _StoredUserAccount(
      userId: 'dev_test_user_001',
      email: devDemoEmail,
      username: 'dev_tester',
      passwordSalt: devSalt,
      passwordHash: _hashWithSalt(devDemoPassword, devSalt),
      profile: devProfile,
      hasCompletedOnboarding: true,
    );

    // 2. Standard Test Lifter Account (regular athlete role for user-level testing)
    const email = legacyDemoEmail;
    const password = legacyDemoPassword;
    const username = 'demo_lifter_4821';
    const uid = 'dev_demo_lifter_4821';
    final profile = UserProfile(
      id: uid,
      email: email,
      emailVerified: true,
      username: username,
      name: 'Demo Lifter',
      experienceLevel: 'Intermediate',
      trainingInterest: 'Hybrid Training',
      linkedProviders: const ['email'],
      role: UserRole.user,
      createdAt: DateTime(2026, 1, 1),
    );
    final salt = _generateSalt();
    _accountsByEmail[email] = _StoredUserAccount(
      userId: uid,
      email: email,
      username: username,
      passwordSalt: salt,
      passwordHash: _hashWithSalt(password, salt),
      profile: profile,
      hasCompletedOnboarding: true,
    );
  }

  List<Workout> _buildStandardTemplates() {
    return [
      Workout(
        id: 'tpl_push',
        userId: 'system_catalog',
        name: 'PPL — Push Hypertrophy A',
        trainingMode: 'Bodybuilding',
        date: DateTime.now(),
        isTemplate: true,
        createdAt: DateTime.now(),
        exercises: [
          WorkoutExercise(
            id: newId(),
            exerciseId: 'ex_bb_bench_press',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            restTimeSeconds: 120,
            sets: [
              ExerciseSet(
                setNumber: 1,
                weight: 40,
                reps: 12,
                rpe: 6.0,
                isWarmup: true,
              ),
              ExerciseSet(setNumber: 2, weight: 80, reps: 8, rpe: 7.5),
              ExerciseSet(setNumber: 3, weight: 90, reps: 6, rpe: 8.5),
              ExerciseSet(setNumber: 4, weight: 95, reps: 5, rpe: 9.0),
            ],
          ),
          WorkoutExercise(
            id: newId(),
            exerciseId: 'ex_overhead_press',
            name: 'Barbell Overhead Press (OHP)',
            muscleGroup: 'Shoulders',
            restTimeSeconds: 90,
            sets: [
              ExerciseSet(setNumber: 1, weight: 50, reps: 8, rpe: 7.5),
              ExerciseSet(setNumber: 2, weight: 55, reps: 8, rpe: 8.5),
              ExerciseSet(setNumber: 3, weight: 55, reps: 8, rpe: 9.0),
            ],
          ),
        ],
      ),
      Workout(
        id: 'tpl_sbd',
        userId: 'system_catalog',
        name: 'Powerlifting Competition SBD Peaking',
        trainingMode: 'Powerlifting',
        date: DateTime.now(),
        isTemplate: true,
        createdAt: DateTime.now(),
        exercises: [
          WorkoutExercise(
            id: newId(),
            exerciseId: 'ex_bb_back_squat',
            name: 'Barbell Back Squat',
            muscleGroup: 'Quadriceps',
            restTimeSeconds: 180,
            sets: [
              ExerciseSet(setNumber: 1, weight: 140, reps: 3, rpe: 7.5),
              ExerciseSet(setNumber: 2, weight: 155, reps: 2, rpe: 8.5),
              ExerciseSet(setNumber: 3, weight: 165, reps: 1, rpe: 9.0),
            ],
          ),
          WorkoutExercise(
            id: newId(),
            exerciseId: 'ex_pause_bench_press',
            name: 'Pause Bench Press',
            muscleGroup: 'Chest',
            restTimeSeconds: 180,
            sets: [
              ExerciseSet(setNumber: 1, weight: 100, reps: 3, rpe: 7.5),
              ExerciseSet(setNumber: 2, weight: 110, reps: 2, rpe: 8.5),
              ExerciseSet(setNumber: 3, weight: 115, reps: 1, rpe: 9.0),
            ],
          ),
          WorkoutExercise(
            id: newId(),
            exerciseId: 'ex_conventional_deadlift',
            name: 'Conventional Barbell Deadlift',
            muscleGroup: 'Back',
            restTimeSeconds: 180,
            sets: [
              ExerciseSet(setNumber: 1, weight: 180, reps: 3, rpe: 8.0),
              ExerciseSet(setNumber: 2, weight: 200, reps: 1, rpe: 8.5),
            ],
          ),
        ],
      ),
    ];
  }

  List<FitnessCourse> _buildOfficialApprovedCatalogCourses() {
    final now = DateTime.now();
    return [
      FitnessCourse(
        id: 'course_1',
        title: 'Biomechanics of the Big 3: Squat, Bench & Deadlift',
        description: 'Master joint moment arms, intra-abdominal bracing, bar-path efficiency, and sticking-point remedies using interactive 3D models.',
        category: 'Powerlifting Fundamentals',
        difficulty: 'Intermediate',
        creatorId: 'platform_owner',
        creatorName: 'Lifting Life Performance Faculty',
        creatorCredentials: 'CSCS • Certified Strength & Biomechanics Team',
        status: CourseStatus.approved,
        approvedByOwnerName: 'Platform Owner',
        approvedAt: now.subtract(const Duration(days: 30)),
        rating: 0.0,
        enrolledCount: 0,
        isEnrolled: false,
        completedLessonIds: const {},
        updatedAt: now.subtract(const Duration(days: 5)),
        lessons: const [
          CourseLesson(
            id: 'les_1_1',
            chapterTitle: 'Chapter 1: Squat Mechanics',
            title: 'High-Bar vs. Low-Bar Hip & Knee Moment Arms',
            durationMinutes: 14,
            relatedExerciseName: 'Barbell Back Squat',
            movementPattern3D: 'squat',
            contentMarkdown:
                '### Mastering the Squat Bar Path\n\n'
                '1. **Center of Mass Alignment**: Regardless of bar placement, the barbell must travel vertically over the mid-foot.\n'
                '2. **360-Degree Bracing**: Pressurized diaphragmatic breathing stabilizes the lumbar spine under heavy axial load.\n'
                '3. **Hip & Knee Simultaneous Break**: Unlock hips and knees together while rooting the tripod foot.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'Where should the barbell remain balanced during a heavy Barbell Back Squat?',
                options: [
                  'Directly over the mid-foot throughout the entire rep',
                  'Over the toes during the descent',
                  'Behind the heels at the bottom',
                ],
                correctOptionIndex: 0,
                explanation: 'Keeping the bar vertically aligned over the mid-foot maximizes mechanical efficiency and prevents forward folding.',
              ),
            ],
          ),
          CourseLesson(
            id: 'les_1_2',
            chapterTitle: 'Chapter 2: Bench Press Architecture',
            title: 'Scapular Retraction, Leg Drive & The J-Curve Path',
            durationMinutes: 16,
            relatedExerciseName: 'Barbell Bench Press',
            movementPattern3D: 'bench',
            contentMarkdown:
                '### The J-Curve Bar Path\n\n'
                'Unlike a vertical piston, optimal bench pressing lowers the bar to the lower sternum and presses slightly back toward the eyes early off the chest to shorten the shoulder flexion moment arm.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'Why do elite bench pressers tuck their elbows ~45-60 degrees instead of flaring at 90 degrees?',
                options: [
                  'To protect the glenohumeral joint and stack wrists over elbows',
                  'To reduce triceps activation completely',
                  'To bounce the bar harder off the sternum',
                ],
                correctOptionIndex: 0,
                explanation: 'A 45-60° elbow tuck preserves subacromial space and creates a strong vertical forearm stack.',
              ),
            ],
          ),
          CourseLesson(
            id: 'les_1_3',
            chapterTitle: 'Chapter 3: Deadlift Leverage',
            title: 'Pulling the Slack Out & Lat Engagement',
            durationMinutes: 18,
            relatedExerciseName: 'Conventional Barbell Deadlift',
            movementPattern3D: 'deadlift',
            contentMarkdown:
                '### Creating Wedge Tension\n\n'
                'Before the plates leave the floor, apply 50% upward tension against the barbell while depressing the scapulae ("bending the bar around your shins").',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'What is the primary role of the Latissimus Dorsi during the deadlift?',
                options: [
                  'Keeping the barbell pinned close to the shins and center of mass',
                  'Extending the knee joint',
                  'Hyperextending the cervical spine',
                ],
                correctOptionIndex: 0,
                explanation: 'Active lats prevent the bar from drifting forward away from the body.',
              ),
            ],
          ),
        ],
      ),
      FitnessCourse(
        id: 'course_2',
        title: 'Hypertrophy Science: Volume Landmarks & Progressive Overload',
        description: 'Learn how to program MEV, MAV, and MRV, select high-stimulus exercises, and regulate RIR/RPE for drug-free muscle growth.',
        category: 'Bodybuilding Fundamentals',
        difficulty: 'Intermediate',
        creatorId: 'platform_owner',
        creatorName: 'Lifting Life Performance Faculty',
        creatorCredentials:
            'MSc Exercise Physiology • Natural Hypertrophy Team',
        status: CourseStatus.approved,
        approvedByOwnerName: 'Platform Owner',
        approvedAt: now.subtract(const Duration(days: 18)),
        rating: 0.0,
        enrolledCount: 0,
        isEnrolled: false,
        updatedAt: now.subtract(const Duration(days: 14)),
        lessons: const [
          CourseLesson(
            id: 'les_2_1',
            chapterTitle: 'Chapter 1: Mechanical Tension',
            title: 'Effective Reps & Lengthened-Partial Hypertrophy',
            durationMinutes: 15,
            relatedExerciseName: 'Romanian Deadlift (RDL)',
            movementPattern3D: 'hinge',
            contentMarkdown:
                '### Mechanical Tension in the Stretched Position\n\n'
                'High motor-unit recruitment combined with slow eccentric velocity in the lengthened range produces superior sarcomereogenesis.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'What proximity to failure (RIR) produces optimal hypertrophy with manageable fatigue on compounds?',
                options: [
                  '1 to 3 Repetitions in Reserve (RPE 7 to 9)',
                  '10 Repetitions in Reserve',
                  'Missing every rep with supramaximal loads',
                ],
                correctOptionIndex: 0,
                explanation: 'Training within 1-3 RIR recruits high-threshold motor units without excessive recovery debt.',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  /// Legacy test fixture loader retained strictly for automated tests (e.g. DemoDataCleanupService verification).
  /// Never called on production startup.
  @visibleForTesting
  void initializeDemoData() {
    _isDemo = true;
    if (_exercises.isEmpty) {
      _exercises.addAll(ExerciseSeedData.build200PlusExercises());
    }

    _currentUser = UserProfile(
      id: 'u_owner_alex',
      email: 'alex@liftinglife.app',
      username: 'alex_titan',
      name: 'Alex Rivera',
      age: 27,
      height: 180,
      weight: 84.5,
      experienceLevel: 'Advanced',
      trainingInterest: 'Hybrid',
      preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri', 'Sat'],
      trainingGoals: const [
        'Build 3D Delts & Back Width',
        '600 kg Powerlifting Total',
        '100% Weekly Training Consistency',
      ],
      tiktokUsername: '@alex_liftinglife',
      units: 'metric',
      isPublicProfile: true,
      hidePersonalRecords: false,
      isPremium: true,
      xpPoints: 3850,
      streakDays: 18,
      role: UserRole.owner,
      achievements: [
        AchievementBadge(
          id: 'b_1',
          title: '1000 LB Club Contender',
          description:
              'Logged Squat, Bench, and Deadlift PRs exceeding 480 kg total.',
          iconName: 'emoji_events',
          xpReward: 500,
          unlockedAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
        AchievementBadge(
          id: 'b_2',
          title: '14-Day Iron Consistency',
          description:
              'Completed scheduled training days for 2 consecutive weeks.',
          iconName: 'local_fire_department',
          xpReward: 300,
          unlockedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
        AchievementBadge(
          id: 'b_3',
          title: 'Biomechanics Scholar',
          description: 'Completed a certified 3D Exercise Technique course.',
          iconName: 'school',
          xpReward: 250,
          unlockedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    );

    if (_goals.isEmpty) {
      _goals.addAll([
        Goal(
          id: newId(),
          userId: _currentUser!.id,
          type: 'calories',
          target: 2650,
          current: 2180,
          unit: 'kcal',
          createdAt: DateTime.now(),
        ),
        Goal(
          id: newId(),
          userId: _currentUser!.id,
          type: 'protein',
          target: 185,
          current: 162,
          unit: 'g',
          createdAt: DateTime.now(),
        ),
        Goal(
          id: newId(),
          userId: _currentUser!.id,
          type: 'water',
          target: 3.5,
          current: 2.8,
          unit: 'L',
          createdAt: DateTime.now(),
        ),
        Goal(
          id: newId(),
          userId: _currentUser!.id,
          type: 'workoutsPerWeek',
          target: 5,
          current: 4,
          unit: 'workouts',
          createdAt: DateTime.now(),
        ),
      ]);
    }

    if (_personalRecords.isEmpty) {
      final now = DateTime.now();
      _personalRecords.addAll([
        PersonalRecord(
          id: 'pr_sq_1',
          exerciseName: 'Barbell Back Squat',
          category: 'Squat',
          weightKg: 170,
          reps: 1,
          estimated1RM: 170,
          date: now.subtract(const Duration(days: 35)),
          isCompetitionLift: true,
        ),
        PersonalRecord(
          id: 'pr_sq_2',
          exerciseName: 'Barbell Back Squat',
          category: 'Squat',
          weightKg: 182.5,
          reps: 1,
          estimated1RM: 182.5,
          date: now.subtract(const Duration(days: 6)),
          isCompetitionLift: true,
        ),
        PersonalRecord(
          id: 'pr_bp_1',
          exerciseName: 'Barbell Bench Press',
          category: 'Bench Press',
          weightKg: 120,
          reps: 1,
          estimated1RM: 120,
          date: now.subtract(const Duration(days: 28)),
          isCompetitionLift: true,
        ),
        PersonalRecord(
          id: 'pr_bp_2',
          exerciseName: 'Barbell Bench Press',
          category: 'Bench Press',
          weightKg: 127.5,
          reps: 1,
          estimated1RM: 127.5,
          date: now.subtract(const Duration(days: 3)),
          isCompetitionLift: true,
        ),
        PersonalRecord(
          id: 'pr_dl_1',
          exerciseName: 'Conventional Barbell Deadlift',
          category: 'Deadlift',
          weightKg: 210,
          reps: 1,
          estimated1RM: 210,
          date: now.subtract(const Duration(days: 21)),
          isCompetitionLift: true,
        ),
        PersonalRecord(
          id: 'pr_dl_2',
          exerciseName: 'Conventional Barbell Deadlift',
          category: 'Deadlift',
          weightKg: 225,
          reps: 1,
          estimated1RM: 225,
          date: now.subtract(const Duration(days: 1)),
          isCompetitionLift: true,
        ),
      ]);
    }

    if (_workouts.isEmpty) {
      final today = DateTime.now();
      _workouts.addAll([
        Workout(
          id: 'w_hist_1',
          userId: _currentUser!.id,
          name: 'Powerlifting SBD Heavy Block',
          trainingMode: 'Powerlifting',
          date: today.subtract(const Duration(days: 3)),
          durationMinutes: 68,
          notes: 'Moved fast at RPE 8.5. Solid bar path on squat.',
          createdAt: today.subtract(const Duration(days: 3)),
          exercises: [
            WorkoutExercise(
              id: newId(),
              exerciseId: 'ex_bb_back_squat',
              name: 'Barbell Back Squat',
              muscleGroup: 'Quadriceps',
              restTimeSeconds: 180,
              sets: [
                ExerciseSet(
                  setNumber: 1,
                  weight: 100,
                  reps: 8,
                  rpe: 6.0,
                  isWarmup: true,
                ),
                ExerciseSet(setNumber: 2, weight: 145, reps: 5, rpe: 7.5),
                ExerciseSet(setNumber: 3, weight: 160, reps: 3, rpe: 8.5),
                ExerciseSet(setNumber: 4, weight: 170, reps: 2, rpe: 9.0),
              ],
            ),
            WorkoutExercise(
              id: newId(),
              exerciseId: 'ex_bb_bench_press',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              restTimeSeconds: 150,
              sets: [
                ExerciseSet(
                  setNumber: 1,
                  weight: 60,
                  reps: 10,
                  rpe: 5.5,
                  isWarmup: true,
                ),
                ExerciseSet(setNumber: 2, weight: 100, reps: 5, rpe: 7.5),
                ExerciseSet(setNumber: 3, weight: 112.5, reps: 4, rpe: 8.5),
                ExerciseSet(setNumber: 4, weight: 117.5, reps: 3, rpe: 9.0),
              ],
            ),
          ],
        ),
        Workout(
          id: 'w_hist_2',
          userId: _currentUser!.id,
          name: 'Bodybuilding Push Hypertrophy',
          trainingMode: 'Bodybuilding',
          date: today.subtract(const Duration(days: 1)),
          durationMinutes: 54,
          notes: 'Great pump on upper chest and lateral delts.',
          createdAt: today.subtract(const Duration(days: 1)),
          exercises: [
            WorkoutExercise(
              id: newId(),
              exerciseId: 'ex_bb_bench_press',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              restTimeSeconds: 120,
              sets: [
                ExerciseSet(
                  setNumber: 1,
                  weight: 60,
                  reps: 12,
                  rpe: 6.0,
                  isWarmup: true,
                ),
                ExerciseSet(setNumber: 2, weight: 95, reps: 8, rpe: 8.0),
                ExerciseSet(setNumber: 3, weight: 100, reps: 8, rpe: 8.5),
                ExerciseSet(setNumber: 4, weight: 102.5, reps: 6, rpe: 9.0),
              ],
            ),
            WorkoutExercise(
              id: newId(),
              exerciseId: 'ex_overhead_press',
              name: 'Barbell Overhead Press (OHP)',
              muscleGroup: 'Shoulders',
              restTimeSeconds: 120,
              sets: [
                ExerciseSet(setNumber: 1, weight: 55, reps: 8, rpe: 7.5),
                ExerciseSet(setNumber: 2, weight: 60, reps: 8, rpe: 8.5),
                ExerciseSet(setNumber: 3, weight: 62.5, reps: 6, rpe: 9.0),
              ],
            ),
          ],
        ),
      ]);
    }

    if (_workoutTemplates.isEmpty) {
      _workoutTemplates.addAll(_buildStandardTemplates());
    }

    _activeWorkoutDraft ??= Workout(
      id: newId(),
      userId: _currentUser!.id,
      name: 'Upper / Chest & Back Hypertrophy',
      trainingMode: 'Bodybuilding',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      exercises: [
        WorkoutExercise(
          id: newId(),
          exerciseId: 'ex_bb_bench_press',
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          restTimeSeconds: 120,
          notes: 'Keep scapulae retracted on bench pad.',
          sets: [
            ExerciseSet(
              setNumber: 1,
              weight: 40,
              reps: 12,
              rpe: 6.0,
              isWarmup: true,
              isCompleted: true,
            ),
            ExerciseSet(
              setNumber: 2,
              weight: 60,
              reps: 8,
              rpe: 7.0,
              isCompleted: true,
            ),
            ExerciseSet(
              setNumber: 3,
              weight: 70,
              reps: 5,
              rpe: 8.0,
              isCompleted: true,
            ),
            ExerciseSet(
              setNumber: 4,
              weight: 75,
              reps: 5,
              rpe: 9.0,
              isCompleted: false,
            ),
          ],
        ),
        WorkoutExercise(
          id: newId(),
          exerciseId: 'ex_lat_pulldown',
          name: 'Wide-Grip Cable Lat Pulldown',
          muscleGroup: 'Back',
          restTimeSeconds: 90,
          sets: [
            ExerciseSet(
              setNumber: 1,
              weight: 55,
              reps: 12,
              rpe: 7.5,
              isCompleted: true,
            ),
            ExerciseSet(
              setNumber: 2,
              weight: 65,
              reps: 10,
              rpe: 8.5,
              isCompleted: false,
            ),
            ExerciseSet(
              setNumber: 3,
              weight: 65,
              reps: 10,
              rpe: 9.0,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );

    if (_programs.isEmpty) {
      _seedTrainingPrograms();
    }

    if (_socialPosts.isEmpty) {
      _seedSocialAndLeaderboards();
    }

    if (_courses.isEmpty) {
      _seedFitnessCourses();
    }

    if (_notifications.isEmpty) {
      _notifications.addAll([
        AppNotification(
          id: 'notif_1',
          title: 'Course Pending Owner Review',
          body: 'Coach Marcus submitted "Advanced Sumo Deadlift Wedge Mastery" for Owner Approval.',
          category: 'course',
          createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        AppNotification(
          id: 'notif_2',
          title: 'New Personal Record Unlocked!',
          body: 'You hit a 225 kg Conventional Deadlift PR (+150 XP).',
          category: 'pr',
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        AppNotification(
          id: 'notif_3',
          title: 'Friend Leaderboard Update',
          body: 'Sarah Chen completed her 4th session this week and is 120 XP behind you!',
          category: 'ranking',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
    }

    if (_meals.isEmpty) {
      final today = DateTime.now();
      _meals.addAll([
        MealEntry(
          id: newId(),
          userId: _currentUser!.id,
          mealType: 'breakfast',
          foodId: 'oats_whey',
          foodName: 'Protein Oats & Berries',
          quantity: 320,
          calories: 540,
          protein: 42,
          carbs: 68,
          fat: 11,
          date: today,
          createdAt: today,
        ),
        MealEntry(
          id: newId(),
          userId: _currentUser!.id,
          mealType: 'lunch',
          foodId: 'steak_rice',
          foodName: 'Sirloin Steak, Jasmine Rice & Broccoli',
          quantity: 450,
          calories: 780,
          protein: 62,
          carbs: 74,
          fat: 24,
          date: today,
          createdAt: today,
        ),
      ]);
    }
  }

  void _seedTrainingPrograms() {
    _programs.addAll([
      // BODYBUILDING PROGRAMS (All 8 Splits)
      TrainingProgram(
        id: 'prog_bb_ppl',
        name: 'Pro Push Pull Legs (PPL 6-Day)',
        mode: 'Bodybuilding',
        splitType: 'Push Pull Legs (PPL)',
        difficulty: 'Intermediate',
        weeksDuration: 12,
        daysPerWeek: 6,
        description: 'High-frequency hypertrophy split hitting every muscle group twice per week with optimal mechanical tension and volume landmarks.',
        deloadGuidance: 'Every 6th week, reduce working sets by 40% and cap RPE at 6.5 to clear systemic fatigue.',
        recoveryGuidance: 'Target 7.5-9 hours of sleep, 1.8-2.2g protein/kg, and 48 hours between identical muscle sessions.',
        isFeatured: true,
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Push A — Chest & Anterior/Lateral Delts',
            focusMuscles: ['Chest', 'Shoulders', 'Triceps'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Bench Press',
                muscleGroup: 'Chest',
                sets: 4,
                repsRange: '6-8',
                targetRpe: 8.5,
                restSeconds: 150,
                intensityGuidance:
                    'Add 2.5 kg once all 4 sets hit 8 reps at RPE 8.5.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Incline Dumbbell Press',
                muscleGroup: 'Chest',
                sets: 3,
                repsRange: '8-12',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance:
                    '2-second eccentric pause in the stretched position.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Lean-Away Cable Lateral Raise',
                muscleGroup: 'Shoulders',
                sets: 4,
                repsRange: '12-15',
                targetRpe: 9.0,
                restSeconds: 60,
                intensityGuidance: 'Take final set to 0 RIR.',
                movementPattern: 'lateral_raise',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Rope Cable Triceps Pushdown',
                muscleGroup: 'Triceps',
                sets: 3,
                repsRange: '10-15',
                targetRpe: 9.0,
                restSeconds: 75,
                intensityGuidance:
                    'Spread the rope apart at full elbow extension.',
                movementPattern: 'pushdown',
              ),
            ],
          ),
          ProgramDay(
            dayNumber: 2,
            title: 'Pull A — Back Width, Thickness & Biceps',
            focusMuscles: ['Back', 'Biceps', 'Rear Delts'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Wide-Grip Cable Lat Pulldown',
                muscleGroup: 'Back',
                sets: 4,
                repsRange: '8-12',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance:
                    'Full scapular depression before elbow flexion.',
                movementPattern: 'pulldown',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Chest-Supported Incline Dumbbell Row',
                muscleGroup: 'Back',
                sets: 3,
                repsRange: '8-10',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance:
                    'Squeeze rhomboids for 1 second at peak contraction.',
                movementPattern: 'row',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Barbell Biceps Curl',
                muscleGroup: 'Biceps',
                sets: 3,
                repsRange: '8-12',
                targetRpe: 9.0,
                restSeconds: 75,
                intensityGuidance:
                    'Strict upper-arm position without lower-back swing.',
                movementPattern: 'curl',
              ),
            ],
          ),
          ProgramDay(
            dayNumber: 3,
            title: 'Legs A — Quad Sweep & Posterior Chain',
            focusMuscles: ['Quadriceps', 'Hamstrings', 'Calves'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 4,
                repsRange: '6-8',
                targetRpe: 8.5,
                restSeconds: 180,
                intensityGuidance:
                    'Full depth below parallel with controlled eccentric.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Romanian Deadlift (RDL)',
                muscleGroup: 'Hamstrings',
                sets: 3,
                repsRange: '8-10',
                targetRpe: 8.5,
                restSeconds: 150,
                intensityGuidance:
                    'Push hips straight back and keep bar against shins.',
                movementPattern: 'hinge',
              ),
              ProgramExercisePrescription(
                exerciseName: '45-Degree Sled Leg Press',
                muscleGroup: 'Quadriceps',
                sets: 3,
                repsRange: '10-15',
                targetRpe: 9.0,
                restSeconds: 120,
                intensityGuidance: 'Deep knee flexion without lumbar rounding.',
                movementPattern: 'leg_press',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_bb_ul',
        name: 'Upper / Lower 4-Day Mass Builder',
        mode: 'Bodybuilding',
        splitType: 'Upper/Lower',
        difficulty: 'Intermediate',
        weeksDuration: 10,
        daysPerWeek: 4,
        description: 'Balanced 4-day split pairing heavy mechanical tension days with metabolic volume sessions.',
        deloadGuidance: 'Deload every 5th week by cutting sets in half.',
        recoveryGuidance:
            'Rest on Wednesday, Saturday, and Sunday for CNS freshness.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Upper Body A (Strength & Density)',
            focusMuscles: ['Chest', 'Back', 'Shoulders', 'Arms'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Bench Press',
                muscleGroup: 'Chest',
                sets: 4,
                repsRange: '6-8',
                targetRpe: 8.5,
                restSeconds: 150,
                intensityGuidance: 'Progressive double-progression.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Strict Bodyweight Pull-Ups',
                muscleGroup: 'Back',
                sets: 4,
                repsRange: '6-10',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance:
                    'Add belt weight once 10 strict reps are achieved.',
                movementPattern: 'pullup',
              ),
            ],
          ),
          ProgramDay(
            dayNumber: 2,
            title: 'Lower Body A (Quads, Hamstrings & Glutes)',
            focusMuscles: ['Quadriceps', 'Hamstrings', 'Glutes'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 4,
                repsRange: '6-8',
                targetRpe: 8.5,
                restSeconds: 180,
                intensityGuidance: 'Maintain upright brace.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Romanian Deadlift (RDL)',
                muscleGroup: 'Hamstrings',
                sets: 4,
                repsRange: '8-10',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance: 'Stretch hamstrings under control.',
                movementPattern: 'hinge',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_bb_fullbody',
        name: '3-Day Full Body Hypertrophy Foundation',
        mode: 'Bodybuilding',
        splitType: 'Full Body',
        difficulty: 'Beginner',
        weeksDuration: 8,
        daysPerWeek: 3,
        description: 'High-efficiency Mon/Wed/Fri full-body architecture maximizing protein synthesis frequency.',
        deloadGuidance: 'Take a 5-day light week after week 8.',
        recoveryGuidance: '48 hours full recovery between sessions.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Full Body Session A',
            focusMuscles: ['Quadriceps', 'Chest', 'Back', 'Core'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 3,
                repsRange: '8-10',
                targetRpe: 8.0,
                restSeconds: 120,
                intensityGuidance: 'Focus on crisp depth and tempo.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Barbell Bench Press',
                muscleGroup: 'Chest',
                sets: 3,
                repsRange: '8-10',
                targetRpe: 8.0,
                restSeconds: 120,
                intensityGuidance: 'Leave 2 reps in reserve.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Wide-Grip Cable Lat Pulldown',
                muscleGroup: 'Back',
                sets: 3,
                repsRange: '10-12',
                targetRpe: 8.0,
                restSeconds: 90,
                intensityGuidance: 'Smooth cadence.',
                movementPattern: 'pulldown',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_bb_brosplit',
        name: '5-Day Classic Golden-Era Bro Split',
        mode: 'Bodybuilding',
        splitType: 'Bro Split',
        difficulty: 'Intermediate',
        weeksDuration: 8,
        daysPerWeek: 5,
        description: 'Dedicated single-body-part focus days (Chest, Back, Shoulders, Legs, Arms) for maximum localized pump and Mind-Muscle Connection.',
        deloadGuidance: 'Deload every 8 weeks.',
        recoveryGuidance: '7 days of local tissue recovery per muscle group.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'International Chest Day',
            focusMuscles: ['Chest'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Bench Press',
                muscleGroup: 'Chest',
                sets: 4,
                repsRange: '6-10',
                targetRpe: 8.5,
                restSeconds: 120,
                intensityGuidance: 'Pyramid up to top set.',
                movementPattern: 'bench',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_bb_adv_hyp',
        name: 'Advanced Specialization Hypertrophy',
        mode: 'Bodybuilding',
        splitType: 'Advanced Hypertrophy',
        difficulty: 'Advanced',
        weeksDuration: 12,
        daysPerWeek: 5,
        description: 'Periodized MEV-to-MRV (Minimum Effective Volume to Maximum Recoverable Volume) mesocycle for advanced physique athletes.',
        deloadGuidance: 'Mandatory reactive deload in Week 6 and Week 12.',
        recoveryGuidance:
            'Track morning HRV and joint readiness before adding sets.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Upper Specialization (Delts & Lats)',
            focusMuscles: ['Shoulders', 'Back', 'Biceps'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Overhead Press (OHP)',
                muscleGroup: 'Shoulders',
                sets: 4,
                repsRange: '6-10',
                targetRpe: 9.0,
                restSeconds: 120,
                intensityGuidance: 'Strict overhead lockout.',
                movementPattern: 'overhead_press',
              ),
            ],
          ),
        ],
      ),

      // POWERLIFTING PROGRAMS (5/3/1, Linear, Percentage, Block Periodization)
      TrainingProgram(
        id: 'prog_pl_531',
        name: '5/3/1 Submaximal Strength & PR Wave',
        mode: 'Powerlifting',
        splitType: '5/3/1 Progression',
        difficulty: 'Intermediate',
        weeksDuration: 12,
        daysPerWeek: 4,
        description: 'Built around a 90% Training Max (TM) with 3-week percentage waves (5s week, 3s week, 5/3/1+ week) for Squat, Bench, Deadlift, and Overhead Press.',
        deloadGuidance: 'Every 4th week is a 40/50/60% deload week.',
        recoveryGuidance:
            'Prioritize sleep, hip/thoracic mobility, and joint warm-ups.',
        isFeatured: true,
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Day 1 — Competition Squat + Pause Variations',
            focusMuscles: ['Quadriceps', 'Glutes', 'Core'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 3,
                repsRange: '5 / 3 / 1+',
                targetRpe: 8.5,
                percentage1RM: 85,
                restSeconds: 210,
                intensityGuidance: 'Week 1: 65/75/85% • Week 2: 70/80/90% • Week 3: 75/85/95% TM.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Pause Barbell Squat',
                muscleGroup: 'Quadriceps',
                sets: 3,
                repsRange: '4',
                targetRpe: 7.5,
                percentage1RM: 72,
                restSeconds: 180,
                intensityGuidance:
                    '2-second motionless pause in the bottom hole.',
                movementPattern: 'squat',
              ),
            ],
          ),
          ProgramDay(
            dayNumber: 2,
            title: 'Day 2 — Competition Pause Bench + Close-Grip',
            focusMuscles: ['Chest', 'Triceps', 'Shoulders'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Pause Bench Press',
                muscleGroup: 'Chest',
                sets: 3,
                repsRange: '5 / 3 / 1+',
                targetRpe: 8.5,
                percentage1RM: 85,
                restSeconds: 180,
                intensityGuidance:
                    'Hold motionless on chest until press command.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Close-Grip Barbell Bench Press',
                muscleGroup: 'Triceps',
                sets: 4,
                repsRange: '6-8',
                targetRpe: 8.0,
                percentage1RM: 74,
                restSeconds: 150,
                intensityGuidance: 'Build lockout speed.',
                movementPattern: 'bench',
              ),
            ],
          ),
          ProgramDay(
            dayNumber: 3,
            title: 'Day 3 — Competition Deadlift + Deficit Pulls',
            focusMuscles: ['Back', 'Hamstrings', 'Glutes'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Conventional Barbell Deadlift',
                muscleGroup: 'Back',
                sets: 3,
                repsRange: '5 / 3 / 1+',
                targetRpe: 8.5,
                percentage1RM: 85,
                restSeconds: 240,
                intensityGuidance:
                    'Pull slack out of the bar before every rep.',
                movementPattern: 'deadlift',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Deficit Barbell Deadlift',
                muscleGroup: 'Back',
                sets: 3,
                repsRange: '4',
                targetRpe: 7.5,
                percentage1RM: 72,
                restSeconds: 180,
                intensityGuidance: '1.5-inch deficit for speed off the floor.',
                movementPattern: 'deadlift',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_pl_block',
        name: '12-Week Competition Block Periodization (Accumulation → Transmutation → Peaking)',
        mode: 'Powerlifting',
        splitType: 'Block Periodization',
        difficulty: 'Advanced',
        weeksDuration: 12,
        daysPerWeek: 4,
        description: 'RPE + Percentage hybrid meet-prep system transitioning from high-volume variations (Front Squat, RDL, Close-Grip) to heavy competition singles at RPE 8.5-9.5.',
        deloadGuidance: 'Taper volume by 60% during Meet Week (Week 12).',
        recoveryGuidance: 'Avoid spinal axial fatigue overlap between Heavy Squat and Heavy Deadlift days.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Primary Squat + Secondary Bench',
            focusMuscles: ['Quadriceps', 'Glutes', 'Chest'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 1,
                repsRange: '1 @ RPE 8 + 4x3 Backoffs',
                targetRpe: 8.0,
                percentage1RM: 90,
                restSeconds: 240,
                intensityGuidance: 'Work up to 1 competition single @ RPE 8 (~90%), then drop 12% for 4x3.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Pause Bench Press',
                muscleGroup: 'Chest',
                sets: 4,
                repsRange: '4',
                targetRpe: 8.0,
                percentage1RM: 82,
                restSeconds: 180,
                intensityGuidance: 'Competition pause on every rep.',
                movementPattern: 'bench',
              ),
            ],
          ),
        ],
      ),
      TrainingProgram(
        id: 'prog_pl_linear',
        name: 'Novice Linear Strength Progression (3x5 SBD)',
        mode: 'Powerlifting',
        splitType: 'Linear Progression',
        difficulty: 'Beginner',
        weeksDuration: 8,
        daysPerWeek: 3,
        description: 'Session-to-session linear load progression on Squat, Bench Press, and Deadlift for rapid foundational strength gains.',
        deloadGuidance: 'Reset weight by 10% if 3x5 stalls twice.',
        recoveryGuidance: 'Rest 48-72 hours between sessions.',
        schedule: const [
          ProgramDay(
            dayNumber: 1,
            title: 'Linear Session A (Squat / Bench / Deadlift)',
            focusMuscles: ['Quadriceps', 'Chest', 'Back'],
            exercises: [
              ProgramExercisePrescription(
                exerciseName: 'Barbell Back Squat',
                muscleGroup: 'Quadriceps',
                sets: 3,
                repsRange: '5',
                targetRpe: 8.0,
                percentage1RM: 80,
                restSeconds: 180,
                intensityGuidance: 'Add 2.5 kg each successful session.',
                movementPattern: 'squat',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Barbell Bench Press',
                muscleGroup: 'Chest',
                sets: 3,
                repsRange: '5',
                targetRpe: 8.0,
                percentage1RM: 80,
                restSeconds: 180,
                intensityGuidance: 'Add 1.25-2.5 kg each session.',
                movementPattern: 'bench',
              ),
              ProgramExercisePrescription(
                exerciseName: 'Conventional Barbell Deadlift',
                muscleGroup: 'Back',
                sets: 1,
                repsRange: '5',
                targetRpe: 8.5,
                percentage1RM: 82,
                restSeconds: 240,
                intensityGuidance: '1 heavy top set of 5 after warm-ups.',
                movementPattern: 'deadlift',
              ),
            ],
          ),
        ],
      ),
    ]);
  }

  void _seedSocialAndLeaderboards() {
    final now = DateTime.now();
    _socialPosts.addAll([
      SocialPost(
        id: 'post_1',
        authorId: 'u_sarah',
        authorUsername: 'sarah_power',
        authorName: 'Sarah Chen',
        authorRoleBadge: 'IPF Powerlifter',
        tiktokHandle: '@sarah_sbd',
        caption: '165 kg Competition Pause Squat moved like RPE 7.5 today! Check the 3D bar path—zero knee valgus out of the hole.',
        postType: 'PR Achievement',
        exerciseName: 'Pause Barbell Squat',
        movementPattern: 'squat',
        prHighlight: '165 kg × 1 @ RPE 7.5 (New PR)',
        likesCount: 342,
        isLikedByMe: true,
        comments: [
          PostComment(
            id: 'c_1',
            authorUsername: 'marcus_coach',
            text: 'Textbook thoracic brace out of the bottom!',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
          PostComment(
            id: 'c_2',
            authorUsername: 'alex_titan',
            text: 'Insane speed, 175 kg is there on meet day!',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      SocialPost(
        id: 'post_2',
        authorId: 'u_marcus',
        authorUsername: 'marcus_coach',
        authorName: 'Coach Marcus Vance',
        authorRoleBadge: 'Certified Coach',
        tiktokHandle: '@coachmarcus_bb',
        caption: 'Stop flaring your elbows at 90° on the Barbell Bench Press! Tuck to ~45-60° to load the sternal pec fibers and protect your shoulders.',
        postType: 'Exercise Demo',
        exerciseName: 'Barbell Bench Press',
        movementPattern: 'bench',
        prHighlight: '3D Biomechanics Breakdown',
        likesCount: 518,
        comments: [
          PostComment(
            id: 'c_3',
            authorUsername: 'elena_hypertrophy',
            text: 'This cue fixed my front delt pain immediately.',
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 7)),
      ),
      SocialPost(
        id: 'post_3',
        authorId: 'u_elena',
        authorUsername: 'elena_hypertrophy',
        authorName: 'Elena Rostova',
        authorRoleBadge: 'Pro Bodybuilder',
        tiktokHandle: '@elena_sculpt',
        caption: 'Week 6 of PPL Hypertrophy! Controlled 3-second eccentric on Romanian Deadlifts is unmatched for hamstring tie-ins.',
        postType: 'Progress',
        exerciseName: 'Romanian Deadlift (RDL)',
        movementPattern: 'hinge',
        prHighlight: '120 kg × 10 @ RPE 8.5',
        likesCount: 289,
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
    ]);

    _leaderboardEntries.addAll([
      const LeaderboardEntry(
        userId: 'u_sarah',
        username: 'sarah_power',
        displayName: 'Sarah Chen',
        tiktokHandle: '@sarah_sbd',
        xpPoints: 4120,
        weeklySessionsCompleted: 5,
        streakDays: 24,
        coursesCompleted: 4,
        powerliftingStrengthIndex: 114.8,
        bestPrSummary: 'Squat 165 kg • Deadlift 195 kg',
        rankDelta: 1,
        isFriend: true,
        experienceLevel: 'Advanced',
        trainingInterest: 'Powerlifting',
      ),
      LeaderboardEntry(
        userId: _currentUser!.id,
        username: _currentUser!.username,
        displayName: '${_currentUser!.name} (You)',
        tiktokHandle: _currentUser!.tiktokUsername,
        xpPoints: _currentUser!.xpPoints,
        weeklySessionsCompleted: 4,
        streakDays: _currentUser!.streakDays,
        coursesCompleted: 3,
        powerliftingStrengthIndex: 112.4,
        bestPrSummary: 'Squat 182.5 kg • Bench 127.5 kg • DL 225 kg',
        hidePersonalRecords: _currentUser!.hidePersonalRecords,
        rankDelta: 2,
        isFriend: true,
        experienceLevel: _currentUser!.experienceLevel,
        trainingInterest: _currentUser!.trainingInterest,
      ),
      const LeaderboardEntry(
        userId: 'u_marcus',
        username: 'marcus_coach',
        displayName: 'Coach Marcus Vance',
        tiktokHandle: '@coachmarcus_bb',
        xpPoints: 3690,
        weeklySessionsCompleted: 5,
        streakDays: 19,
        coursesCompleted: 6,
        powerliftingStrengthIndex: 109.2,
        bestPrSummary: 'Bench 150 kg • Squat 205 kg',
        rankDelta: -1,
        isFriend: true,
        experienceLevel: 'Advanced',
        trainingInterest: 'Bodybuilding',
      ),
      const LeaderboardEntry(
        userId: 'u_elena',
        username: 'elena_hypertrophy',
        displayName: 'Elena Rostova',
        tiktokHandle: '@elena_sculpt',
        xpPoints: 3410,
        weeklySessionsCompleted: 4,
        streakDays: 15,
        coursesCompleted: 3,
        powerliftingStrengthIndex: 104.5,
        bestPrSummary: 'RDL 120 kg × 10 • Hip Thrust 200 kg',
        rankDelta: 1,
        isFriend: true,
        experienceLevel: 'Advanced',
        trainingInterest: 'Bodybuilding',
      ),
      const LeaderboardEntry(
        userId: 'u_devon',
        username: 'devon_lifts',
        displayName: 'Devon Brooks',
        tiktokHandle: '@devon_iron',
        xpPoints: 2890,
        weeklySessionsCompleted: 3,
        streakDays: 9,
        coursesCompleted: 2,
        powerliftingStrengthIndex: 98.7,
        bestPrSummary: 'Deadlift 200 kg • OHP 80 kg',
        rankDelta: 0,
        isFriend: true,
        experienceLevel: 'Intermediate',
        trainingInterest: 'Hybrid',
      ),
      const LeaderboardEntry(
        userId: 'u_kai',
        username: 'kai_strength',
        displayName: 'Kai Nakamura',
        tiktokHandle: '@kai_barbell',
        xpPoints: 2640,
        weeklySessionsCompleted: 4,
        streakDays: 11,
        coursesCompleted: 2,
        powerliftingStrengthIndex: 101.2,
        bestPrSummary: 'Front Squat 140 kg',
        rankDelta: 3,
        isFriend: false,
        experienceLevel: 'Intermediate',
        trainingInterest: 'Powerlifting',
      ),
    ]);

    _challenges.addAll([
      const FitnessChallenge(
        id: 'chal_1',
        title: '4-Session Weekly Consistency',
        description: 'Complete 4 structured workouts this week. Frequency rewards are capped at 5 sessions/week to encourage healthy recovery.',
        category: 'Weekly Consistency',
        currentProgress: 3,
        targetValue: 4,
        unit: 'sessions',
        rewardXp: 300,
        participantsCount: 148,
        isJoined: true,
        daysRemaining: 3,
      ),
      const FitnessChallenge(
        id: 'chal_2',
        title: 'Friend-vs-Friend: Alex vs. Sarah Consistency Duel',
        description: 'Hit your planned training days + finish 1 Technique Lesson this week without skipping warm-up sets.',
        category: 'Friend-vs-Friend',
        currentProgress: 4,
        targetValue: 5,
        unit: 'milestones',
        rewardXp: 450,
        participantsCount: 2,
        isJoined: true,
        daysRemaining: 4,
      ),
      const FitnessChallenge(
        id: 'chal_3',
        title: 'October SBD Technique & Mobility Mastery',
        description: 'Log 12 quality compound sessions at RPE 7-8.5 and complete 2 Sports Science lessons.',
        category: 'Monthly Challenge',
        currentProgress: 9,
        targetValue: 12,
        unit: 'sessions',
        rewardXp: 750,
        participantsCount: 1420,
        isJoined: true,
        daysRemaining: 10,
      ),
    ]);
  }

  void _seedFitnessCourses() {
    final now = DateTime.now();
    _courses.addAll([
      FitnessCourse(
        id: 'course_1',
        title: 'Biomechanics of the Big 3: Squat, Bench & Deadlift',
        description: 'Master joint moment arms, intra-abdominal bracing, bar-path efficiency, and sticking-point remedies using interactive 3D models.',
        category: 'Powerlifting Fundamentals',
        difficulty: 'Intermediate',
        creatorId: 'u_owner_alex',
        creatorName: 'Alex Rivera (App Owner)',
        creatorCredentials: 'CSCS • Elite Powerlifter',
        status: CourseStatus.approved,
        approvedByOwnerName: 'Alex Rivera (Owner)',
        approvedAt: now.subtract(const Duration(days: 30)),
        rating: 4.95,
        enrolledCount: 1840,
        isEnrolled: true,
        completedLessonIds: const {'les_1_1'},
        updatedAt: now.subtract(const Duration(days: 5)),
        lessons: const [
          CourseLesson(
            id: 'les_1_1',
            chapterTitle: 'Chapter 1: Squat Mechanics',
            title: 'High-Bar vs. Low-Bar Hip & Knee Moment Arms',
            durationMinutes: 14,
            relatedExerciseName: 'Barbell Back Squat',
            movementPattern3D: 'squat',
            contentMarkdown:
                '### Mastering the Squat Bar Path\n\n'
                '1. **Center of Mass Alignment**: Regardless of bar placement, the barbell must travel vertically over the mid-foot.\n'
                '2. **360-Degree Bracing**: Pressurized diaphragmatic breathing stabilizes the lumbar spine under heavy axial load.\n'
                '3. **Hip & Knee Simultaneous Break**: Unlock hips and knees together while rooting the tripod foot.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'Where should the barbell remain balanced during a heavy Barbell Back Squat?',
                options: [
                  'Directly over the mid-foot throughout the entire rep',
                  'Over the toes during the descent',
                  'Behind the heels at the bottom',
                ],
                correctOptionIndex: 0,
                explanation: 'Keeping the bar vertically aligned over the mid-foot maximizes mechanical efficiency and prevents forward folding.',
              ),
            ],
          ),
          CourseLesson(
            id: 'les_1_2',
            chapterTitle: 'Chapter 2: Bench Press Architecture',
            title: 'Scapular Retraction, Leg Drive & The J-Curve Path',
            durationMinutes: 16,
            relatedExerciseName: 'Barbell Bench Press',
            movementPattern3D: 'bench',
            contentMarkdown:
                '### The J-Curve Bar Path\n\n'
                'Unlike a vertical piston, optimal bench pressing lowers the bar to the lower sternum and presses slightly back toward the eyes early off the chest to shorten the shoulder flexion moment arm.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'Why do elite bench pressers tuck their elbows ~45-60 degrees instead of flaring at 90 degrees?',
                options: [
                  'To protect the glenohumeral joint and stack wrists over elbows',
                  'To reduce triceps activation completely',
                  'To bounce the bar harder off the sternum',
                ],
                correctOptionIndex: 0,
                explanation: 'A 45-60° elbow tuck preserves subacromial space and creates a strong vertical forearm stack.',
              ),
            ],
          ),
          CourseLesson(
            id: 'les_1_3',
            chapterTitle: 'Chapter 3: Deadlift Leverage',
            title: 'Pulling the Slack Out & Lat Engagement',
            durationMinutes: 18,
            relatedExerciseName: 'Conventional Barbell Deadlift',
            movementPattern3D: 'deadlift',
            contentMarkdown:
                '### Creating Wedge Tension\n\n'
                'Before the plates leave the floor, apply 50% upward tension against the barbell while depressing the scapulae ("bending the bar around your shins").',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'What is the primary role of the Latissimus Dorsi during the deadlift?',
                options: [
                  'Keeping the barbell pinned close to the shins and center of mass',
                  'Extending the knee joint',
                  'Hyperextending the cervical spine',
                ],
                correctOptionIndex: 0,
                explanation: 'Active lats prevent the bar from drifting forward away from the body.',
              ),
            ],
          ),
        ],
        reviews: [
          CourseReview(
            id: 'rev_1',
            username: 'sarah_power',
            rating: 5,
            comment: 'The 3D avatar views inside each lesson made bar path click immediately!',
            createdAt: now.subtract(const Duration(days: 10)),
          ),
        ],
      ),
      FitnessCourse(
        id: 'course_2',
        title: 'Hypertrophy Science: Volume Landmarks & Progressive Overload',
        description: 'Learn how to program MEV, MAV, and MRV, select high-stimulus exercises, and regulate RIR/RPE for drug-free muscle growth.',
        category: 'Bodybuilding Fundamentals',
        difficulty: 'Intermediate',
        creatorId: 'u_elena',
        creatorName: 'Elena Rostova',
        creatorCredentials: 'MSc Exercise Physiology • Pro Natural Bodybuilder',
        status: CourseStatus.approved,
        approvedByOwnerName: 'Alex Rivera (Owner)',
        approvedAt: now.subtract(const Duration(days: 18)),
        rating: 4.9,
        enrolledCount: 1120,
        isEnrolled: true,
        updatedAt: now.subtract(const Duration(days: 14)),
        lessons: const [
          CourseLesson(
            id: 'les_2_1',
            chapterTitle: 'Chapter 1: Mechanical Tension',
            title: 'Effective Reps & Lengthened-Partial Hypertrophy',
            durationMinutes: 15,
            relatedExerciseName: 'Romanian Deadlift (RDL)',
            movementPattern3D: 'hinge',
            contentMarkdown:
                '### Mechanical Tension in the Stretched Position\n\n'
                'High motor-unit recruitment combined with slow eccentric velocity in the lengthened range produces superior sarcomereogenesis.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'What proximity to failure (RIR) produces optimal hypertrophy with manageable fatigue on compounds?',
                options: [
                  '1 to 3 Repetitions in Reserve (RPE 7 to 9)',
                  '10 Repetitions in Reserve',
                  'Missing every rep with supramaximal loads',
                ],
                correctOptionIndex: 0,
                explanation: 'Training within 1-3 RIR recruits high-threshold motor units without excessive recovery debt.',
              ),
            ],
          ),
        ],
      ),
      // PENDING REVIEW COURSE (Demonstrates mandatory Owner Approval queue!)
      FitnessCourse(
        id: 'course_pending_1',
        title: 'Advanced Sumo Deadlift Wedge & Hip Mobility Mastery',
        description: 'Community-submitted coaching course covering stance width, external hip rotation, and hook grip mechanics.',
        category: 'Exercise Technique',
        difficulty: 'Advanced',
        creatorId: 'u_marcus',
        creatorName: 'Coach Marcus Vance',
        creatorCredentials: 'USAPL Senior Coach',
        status: CourseStatus.pendingReview,
        rating: 0.0,
        enrolledCount: 0,
        updatedAt: now.subtract(const Duration(hours: 2)),
        lessons: const [
          CourseLesson(
            id: 'les_p_1',
            chapterTitle: 'Chapter 1: The Hip Wedge',
            title: 'Aligning Shin Angles Vertically in the Sumo Setup',
            durationMinutes: 12,
            relatedExerciseName: 'Conventional Barbell Deadlift',
            movementPattern3D: 'deadlift',
            contentMarkdown:
                '### Vertical Shins in Sumo\n\n'
                'Open the hips externally so knees track directly over the ankle joint in both frontal and sagittal planes.',
            quizQuestions: [
              CourseQuizQuestion(
                question: 'In a proper Sumo Deadlift setup, how should the shins be oriented from the front view?',
                options: [
                  'Perpendicular (vertical) to the floor directly over the ankles',
                  'Collapsed inward inside the ankles',
                  'Far outside the toes',
                ],
                correctOptionIndex: 0,
                explanation: 'Vertical shins maximize force transfer from the adductors and quads.',
              ),
            ],
          ),
        ],
      ),
      // CHANGES REQUESTED COURSE
      FitnessCourse(
        id: 'course_changes_1',
        title: 'Evidence-Based Gym Nutrition & Peri-Workout Fueling',
        description: 'Complete macronutrient periodization guide for hypertrophy and strength phases.',
        category: 'Nutrition Education',
        difficulty: 'Beginner',
        creatorId: 'u_devon',
        creatorName: 'Devon Brooks, RD',
        creatorCredentials: 'Sports Dietitian',
        status: CourseStatus.changesRequested,
        reviewerFeedback: 'Great macro breakdown! Please add a safety note on safe hydration and electrolyte intake before final publication.',
        rating: 0.0,
        enrolledCount: 0,
        updatedAt: now.subtract(const Duration(days: 1)),
        lessons: const [
          CourseLesson(
            id: 'les_c_1',
            chapterTitle: 'Chapter 1: Protein Leucine Thresholds',
            title: 'Optimizing Daily Protein Distribution',
            durationMinutes: 11,
            movementPattern3D: 'squat',
            contentMarkdown: '### Daily Protein Targets\n\nAim for 1.6g to 2.2g of protein per kg of bodyweight spread across 3-5 feedings.',
          ),
        ],
      ),
    ]);

    _auditLogs.addAll([
      AdminAuditLog(
        id: 'aud_1',
        actorId: 'u_owner_alex',
        actorName: 'Alex Rivera',
        actorRole: UserRole.owner,
        action: 'APPROVED_COURSE',
        targetTitle:
            'Hypertrophy Science: Volume Landmarks & Progressive Overload',
        details:
            'Verified all 3D demonstrations, safety cues, and quiz accuracy.',
        timestamp: now.subtract(const Duration(days: 18)),
      ),
      AdminAuditLog(
        id: 'aud_2',
        actorId: 'u_owner_alex',
        actorName: 'Alex Rivera',
        actorRole: UserRole.owner,
        action: 'REQUESTED_CHANGES',
        targetTitle: 'Evidence-Based Gym Nutrition & Peri-Workout Fueling',
        details: 'Requested addition of hydration safety guidelines.',
        timestamp: now.subtract(const Duration(days: 1)),
      ),
    ]);

    _reports.addAll([
      AbuseReport(
        id: 'rep_1',
        reporterUsername: 'elena_hypertrophy',
        targetType: 'Post',
        targetId: 'post_spam_99',
        targetSummary: 'Fake 400 kg Bench Press claim with spam link',
        reason: 'Fraudulent workout submission / external spam link',
        status: 'Open',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    ]);
  }

  // ============================================================================
  // AUTHENTICATION, OAUTH (FACEBOOK / APPLE / EMAIL), ONBOARDING & ACCOUNT LINKING
  // ============================================================================
  bool isUsernameTaken(String candidate) {
    final clean = candidate.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final reserved = {'admin', 'owner', 'support', 'system', 'liftinglife'};
    if (reserved.contains(clean)) return true;
    for (final account in _accountsByEmail.values) {
      if (account.username.trim().toLowerCase() == clean &&
          account.userId != _currentUser?.id) {
        return true;
      }
    }
    return false;
  }

  /// Restores an existing session on app launch.
  ///
  /// The authoritative source is the Supabase Auth session (persisted in the
  /// Keychain/Keystore via [SecureSessionStorage]). Only a valid session whose
  /// email is confirmed is restored — users are never asked to verify again,
  /// and unverified accounts never reach protected screens.
  Future<bool> tryRestorePersistedSession() async {
    // Supabase Auth is authoritative whenever it is configured: only a valid,
    // email-confirmed server session can restore access.
    if (emailAuthBackend.isConfigured) {
      try {
        final identity = await emailAuthBackend
            .restoreVerifiedSession()
            .timeout(const Duration(seconds: 8));
        if (identity == null || !identity.emailConfirmed) {
          await SecureSessionStorage.instance.clearActiveSession();
          return false;
        }
        await _establishVerifiedSession(identity);
        return true;
      } catch (_) {
        return false;
      }
    }

    if (!isDevelopmentDemoAvailable) return false;
    // Local encrypted snapshot fallback (unconfigured builds + automated
    // tests). Never used when Supabase is configured.
    try {
      final decoded = await SecureSessionStorage.instance
          .readValidSessionSnapshot()
          .timeout(const Duration(seconds: 3));
      if (decoded == null) return false;

      final userId = decoded['userId']?.toString();
      final email = decoded['email']?.toString().toLowerCase();
      if (userId == null || email == null) {
        await SecureSessionStorage.instance.clearActiveSession();
        return false;
      }

      if ((userId == 'dev_demo_lifter_4821' || userId == 'dev_test_user_001') &&
          !isDevelopmentDemoAvailable) {
        return false;
      }

      final account = _accountsByEmail[email];
      UserProfile? profile = account?.profile;
      var onboardingDone =
          account?.hasCompletedOnboarding ??
          decoded['onboardingCompleted'] == true;

      if (profile == null) {
        final stored = await SecureSessionStorage.instance.readUserScopedJson(
          userId: userId,
          collection: 'profile',
        );
        if (stored is Map) {
          profile = UserProfile.fromMap(Map<String, dynamic>.from(stored));
          onboardingDone = decoded['onboardingCompleted'] == true;
        }
      }
      if (profile == null || !profile.emailVerified) {
        await SecureSessionStorage.instance.clearActiveSession();
        return false;
      }

      profile = profile.copyWith(email: email, emailVerified: true);
      _accountsByEmail[email] = _StoredUserAccount(
        userId: userId,
        email: email,
        username: profile.username,
        profile: profile,
        passwordSalt: account?.passwordSalt,
        passwordHash: account?.passwordHash,
        hasCompletedOnboarding: onboardingDone,
      );
      _currentUser = profile;
      _hasCompletedOnboarding = onboardingDone;
      _isAuthenticated = true;
      await _loadUserIsolatedState(userId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Builds the local profile for a backend-verified identity, loads that
  /// user's isolated data, and persists the session snapshot.
  Future<void> _establishVerifiedSession(VerifiedIdentity identity) async {
    final email = identity.email.trim().toLowerCase();
    final existing = _accountsByEmail[email];

    UserProfile? profile = existing?.profile;
    bool onboardingDone =
        existing?.hasCompletedOnboarding ?? identity.onboardingCompleted;

    if (profile == null) {
      final stored = await SecureSessionStorage.instance.readUserScopedJson(
        userId: identity.userId,
        collection: 'profile',
      );
      if (stored is Map) {
        profile = UserProfile.fromMap(Map<String, dynamic>.from(stored));
      }
      final snapshot = await SecureSessionStorage.instance
          .readValidSessionSnapshot();
      if (snapshot != null &&
          snapshot['userId']?.toString() == identity.userId &&
          snapshot['onboardingCompleted'] == true) {
        onboardingDone = true;
      }
    }

    final username = (identity.username?.trim().isNotEmpty ?? false)
        ? identity.username!.trim()
        : (_pendingUsername ?? email.split('@').first);

    profile =
        (profile ??
                UserProfile(
                  id: identity.userId,
                  email: email,
                  username: username,
                  name: username,
                  linkedProviders: const ['email'],
                  role: UserRole.user, // New accounts are never Owner/Admin
                  createdAt: DateTime.now(),
                ))
            .copyWith(email: email, emailVerified: true);

    _accountsByEmail[email] = _StoredUserAccount(
      userId: identity.userId,
      email: email,
      username: profile.username,
      profile: profile,
      hasCompletedOnboarding: onboardingDone,
    );

    _currentUser = profile;
    _hasCompletedOnboarding = onboardingDone;
    _isAuthenticated = true;
    _lastAuthError = null;
    _clearPendingVerificationState();
    await _loadUserIsolatedState(profile.id);
    await _persistActiveSession();
    notifyListeners();
  }

  /// True when Supabase Auth is configured and available for registration.
  bool get isEmailAuthConfigured => emailAuthBackend.isConfigured;

  /// Creates the account in Supabase Auth and asks Supabase to send the
  /// 6-digit verification email.
  ///
  /// The app never generates, stores, logs or emails OTP codes itself:
  /// Supabase owns the password, the code, its expiry and its rate limits.
  Future<EmailAuthOutcome> registerWithEmail({
    required String username,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();
    _rememberSession = true;
    _lastAuthError = null;

    final existing = _accountsByEmail[cleanEmail];
    if (existing != null && existing.profile.emailVerified) {
      const outcome = EmailAuthOutcome(EmailAuthStatus.emailAlreadyRegistered);
      _lastAuthError = outcome.message;
      notifyListeners();
      return outcome;
    }

    _pendingEmail = cleanEmail;
    _pendingUsername = cleanUsername;

    final outcome = await emailAuthBackend.signUp(
      email: cleanEmail,
      password: password,
      username: cleanUsername,
    );

    if (!outcome.isSuccess) {
      _lastAuthError = outcome.message;
      notifyListeners();
      return outcome;
    }

    // Keep an unverified local profile so the OTP screen can display the
    // address and the verified profile can be created with the username the
    // user chose. Unverified accounts are never authenticated.
    final unverifiedProfile = UserProfile(
      id: existing?.userId ?? newId(),
      email: cleanEmail,
      emailVerified: false,
      username: cleanUsername,
      name: cleanUsername,
      linkedProviders: const ['email'],
      role: UserRole.user,
      createdAt: DateTime.now(),
    );
    _accountsByEmail[cleanEmail] = _StoredUserAccount(
      userId: unverifiedProfile.id,
      email: cleanEmail,
      username: cleanUsername,
      profile: unverifiedProfile,
      hasCompletedOnboarding: false,
    );

    _currentUser = null;
    _isAuthenticated = false;
    _hasCompletedOnboarding = false;
    notifyListeners();
    return outcome;
  }

  /// Verifies the Supabase-emailed 6-digit signup code and, on success,
  /// establishes the authenticated session + unlocks onboarding.
  Future<EmailAuthOutcome> verifySignupCode({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final outcome = await emailAuthBackend.verifySignupCode(
      email: cleanEmail,
      token: token.trim(),
    );

    if (!outcome.isSuccess || outcome.identity == null) {
      _lastAuthError = outcome.message;
      notifyListeners();
      return outcome;
    }

    _rememberSession = true;
    await _establishVerifiedSession(outcome.identity!);
    return outcome;
  }

  /// Asks Supabase to email a fresh signup code (server-enforced limits).
  Future<EmailAuthOutcome> resendSignupCode({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    final outcome = await emailAuthBackend.resendSignupCode(email: cleanEmail);
    _lastAuthError = outcome.isSuccess ? null : outcome.message;
    notifyListeners();
    return outcome;
  }

  /// Drops the in-flight registration (used when the user edits their email).
  void clearPendingEmailRegistration() {
    _clearPendingVerificationState();
    notifyListeners();
  }

  /// Signs in through Supabase Auth. Used by the production login screen;
  /// [signIn] remains the legacy in-memory path for automated tests.
  Future<AuthActionResult> signInWithEmail({
    required String email,
    required String password,
    bool rememberSession = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _rememberSession = rememberSession;
    _lastAuthError = null;

    if (isDevelopmentDemoAvailable &&
        (cleanEmail == devDemoEmail || cleanEmail == legacyDemoEmail)) {
      return signIn(
        email: cleanEmail,
        password: password,
        rememberSession: rememberSession,
      );
    }

    if (cleanEmail.isEmpty || password.isEmpty) {
      const result = AuthActionResult(
        isSuccess: false,
        message: 'Please enter both your email address and password.',
      );
      _lastAuthError = result.message;
      notifyListeners();
      return result;
    }

    final outcome = await emailAuthBackend.signInWithPassword(
      email: cleanEmail,
      password: password,
    );

    if (!outcome.isSuccess) {
      _isAuthenticated = false;
      final requiresVerification =
          outcome.status == EmailAuthStatus.emailNotConfirmed;
      if (requiresVerification) {
        _pendingEmail = cleanEmail;
      }
      final message = requiresVerification
          ? 'Your email address has not been verified yet. Enter the 6-digit code we sent you.'
          : outcome.message;
      _lastAuthError = message;
      notifyListeners();
      return AuthActionResult(
        isSuccess: false,
        message: message,
        requiresEmailVerification: requiresVerification,
      );
    }

    final identity = outcome.identity;
    if (identity == null) {
      const result = AuthActionResult(
        isSuccess: false,
        message: 'Unable to sign in. Please try again.',
      );
      _lastAuthError = result.message;
      notifyListeners();
      return result;
    }

    await _establishVerifiedSession(identity);
    return const AuthActionResult(
      isSuccess: true,
      message: 'Signed in successfully.',
    );
  }

  Future<EmailAuthOutcome> sendPasswordResetCode({required String email}) =>
      emailAuthBackend.sendPasswordResetCode(email: email.trim().toLowerCase());

  /// Verifies the recovery code and updates the password in Supabase Auth.
  Future<EmailAuthOutcome> resetPasswordWithCode({
    required String email,
    required String token,
    required String newPassword,
  }) => emailAuthBackend.verifyRecoveryCodeAndUpdatePassword(
    email: email.trim().toLowerCase(),
    token: token.trim(),
    newPassword: newPassword,
  );

  void restoreAuthenticatedSession() {
    if (_currentUser == null) {
      _lastAuthError =
          'No active session found. Please sign in with your credentials.';
      _isAuthenticated = false;
      notifyListeners();
      return;
    }
    _isAuthenticated = true;
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<void> _persistActiveSession() async {
    final user = _currentUser;
    if (user == null || !_isAuthenticated) return;
    if (!_rememberSession) {
      await SecureSessionStorage.instance.clearActiveSession();
      return;
    }
    // Profile/onboarding metadata only. Auth tokens are persisted by the
    // Supabase SDK itself through SecureSessionStorage (Keychain/Keystore).
    await SecureSessionStorage.instance.saveSessionSnapshot(
      userId: user.id,
      email: user.email.toLowerCase(),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
      onboardingCompleted: _hasCompletedOnboarding,
    );
    await SecureSessionStorage.instance.saveUserScopedJson(
      userId: user.id,
      collection: 'profile',
      jsonEncodable: user.toMap(),
    );
  }

  Future<void> _saveCurrentUserIsolatedState() async {
    final user = _currentUser;
    if (user == null) return;
    final uid = user.id;
    // Capture every collection before the first await. Logout/account switches
    // must not cause another user's data (or cleared lists) to be saved here.
    final workoutSnapshot = {'items': _workouts.map((w) => w.toMap()).toList()};
    final recordSnapshot = {'items': _personalRecords.map((pr) => pr.toMap()).toList()};
    final draftSnapshot = {'draft': _activeWorkoutDraft?.toMap()};
    _workoutsByUser[uid] = List<Workout>.from(_workouts);
    _prsByUser[uid] = List<PersonalRecord>.from(_personalRecords);
    _draftByUser[uid] = _activeWorkoutDraft;

    final accountKey = user.email.trim().toLowerCase();
    final existingAccount = _accountsByEmail[accountKey];
    if (existingAccount != null) {
      _accountsByEmail[accountKey] = existingAccount.copyWith(
        profile: user,
        username: user.username,
        hasCompletedOnboarding: _hasCompletedOnboarding,
      );
    }

    await Future.wait([
      SecureSessionStorage.instance.saveUserScopedJson(
      userId: uid,
      collection: 'profile',
      jsonEncodable: user.toMap(),
      ),
      SecureSessionStorage.instance.saveUserScopedJson(
      userId: uid,
      collection: 'workouts',
      jsonEncodable: workoutSnapshot,
      ),
      SecureSessionStorage.instance.saveUserScopedJson(
      userId: uid,
      collection: 'personal_records',
      jsonEncodable: recordSnapshot,
      ),
      SecureSessionStorage.instance.saveUserScopedJson(
      userId: uid,
      collection: 'active_draft',
      jsonEncodable: draftSnapshot,
      ),
    ]);
  }

  Future<void> _loadUserIsolatedState(String userId) async {
    if (_currentUser?.id != userId) return;
    _workouts
      ..clear()
      ..addAll(_workoutsByUser[userId] ?? const <Workout>[]);
    _personalRecords
      ..clear()
      ..addAll(_prsByUser[userId] ?? const <PersonalRecord>[]);
    _activeWorkoutDraft = _draftByUser[userId];

    if (_workouts.isEmpty) {
      final storedWorkouts = await SecureSessionStorage.instance
          .readUserScopedJson(userId: userId, collection: 'workouts');
      if (_currentUser?.id != userId) return;
      if (storedWorkouts is Map && storedWorkouts['items'] is List) {
        final rawList = storedWorkouts['items'] as List;
        final loaded = rawList
            .whereType<Map>()
            .map((m) => Workout.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _workouts.addAll(loaded);
        _workoutsByUser[userId] = List<Workout>.from(loaded);
      }
    }

    if (_personalRecords.isEmpty) {
      final storedPrs = await SecureSessionStorage.instance.readUserScopedJson(
        userId: userId,
        collection: 'personal_records',
      );
      if (_currentUser?.id != userId) return;
      if (storedPrs is Map && storedPrs['items'] is List) {
        final rawList = storedPrs['items'] as List;
        final loaded = rawList
            .whereType<Map>()
            .map((m) => PersonalRecord.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        _personalRecords.addAll(loaded);
        _prsByUser[userId] = List<PersonalRecord>.from(loaded);
      }
    }

    if (_activeWorkoutDraft == null) {
      final storedDraft = await SecureSessionStorage.instance
          .readUserScopedJson(userId: userId, collection: 'active_draft');
      if (_currentUser?.id != userId) return;
      if (_activeWorkoutDraft == null && storedDraft is Map && storedDraft['draft'] is Map) {
        _activeWorkoutDraft = Workout.fromMap(
          Map<String, dynamic>.from(storedDraft['draft'] as Map),
        );
        _draftByUser[userId] = _activeWorkoutDraft;
      }
    }

    // Apply per-user course enrollment state
    final enrolledSet = _enrolledCourseIdsByUser[userId] ?? const <String>{};
    final completedByCourse =
        _completedLessonsByUser[userId] ?? const <String, Set<String>>{};
    for (int i = 0; i < _courses.length; i++) {
      final c = _courses[i];
      _courses[i] = c.copyWith(
        isEnrolled: enrolledSet.contains(c.id),
        completedLessonIds: completedByCourse[c.id] ?? const <String>{},
      );
    }

    _syncCurrentUserLeaderboardEntry();
  }

  /// Enforces Row-Level Security (RLS) in the service layer:
  /// User A cannot read User B's private workout records.
  List<Workout> getWorkoutsForUser({
    required String requestingUserId,
    required String targetUserId,
  }) {
    if (requestingUserId.trim().isEmpty || requestingUserId != targetUserId) {
      throw StateError(
        'RLS Policy Violation: User "$requestingUserId" is not authorized to read private workouts belonging to "$targetUserId".',
      );
    }
    return List.unmodifiable(
      _workoutsByUser[targetUserId] ?? const <Workout>[],
    );
  }

  AuthActionResult signIn({
    required String email,
    required String password,
    bool rememberSession = true,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    _rememberSession = rememberSession;
    _lastAuthError = null;

    if (cleanEmail == legacyDemoEmail || cleanEmail == devDemoEmail) {
      if (!isDevelopmentDemoAvailable) {
        return const AuthActionResult(
          isSuccess: false,
          message: 'The demo account is available only in local development builds.',
        );
      }
      // Also handles a hot reload from an older build that never seeded it,
      // or a legacy restored snapshot without local credential hashes.
      if (_accountsByEmail[cleanEmail]?.passwordHash == null) {
        _addDevelopmentDemoAccount();
      }
    }

    if (cleanEmail.isEmpty || password.isEmpty) {
      _lastAuthError = 'Please enter both your email address and password.';
      notifyListeners();
      return AuthActionResult(isSuccess: false, message: _lastAuthError!);
    }

    final account = _accountsByEmail[cleanEmail];
    if (account == null) {
      _isAuthenticated = false;
      _lastAuthError = 'Invalid email or password. Please verify your credentials or create an account.';
      notifyListeners();
      return AuthActionResult(isSuccess: false, message: _lastAuthError!);
    }

    final passwordSalt = account.passwordSalt;
    final passwordHash = account.passwordHash;
    if (passwordSalt == null ||
        passwordHash == null ||
        _hashWithSalt(password, passwordSalt) != passwordHash) {
      _isAuthenticated = false;
      _lastAuthError = 'Invalid email or password. Please try again.';
      notifyListeners();
      return AuthActionResult(isSuccess: false, message: _lastAuthError!);
    }

    if (!account.profile.emailVerified) {
      _isAuthenticated = false;
      _pendingEmail = account.email;
      _pendingUsername = account.username;
      _lastAuthError = 'Your email address has not been verified yet. Please enter your 6-digit verification code.';
      notifyListeners();
      return AuthActionResult(
        isSuccess: false,
        message: _lastAuthError!,
        requiresEmailVerification: true,
      );
    }

    _currentUser = account.profile;
    _isDemo = account.userId == 'dev_demo_lifter_4821' ||
        account.userId == 'dev_test_user_001';
    _hasCompletedOnboarding = account.hasCompletedOnboarding;
    _isAuthenticated = true;
    unawaited(_loadUserIsolatedState(account.userId));
    unawaited(_persistActiveSession());
    notifyListeners();
    return const AuthActionResult(
      isSuccess: true,
      message: 'Signed in successfully.',
    );
  }

  AuthActionResult signInWithOAuthProvider({
    required String provider, // 'facebook' or 'apple'
    required String email,
    required String displayName,
    required bool isFirstTimeUser,
  }) {
    if (!kDebugMode) {
      return const AuthActionResult(isSuccess: false, message: 'Use a configured authentication provider.');
    }
    final cleanProvider = provider.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    _rememberSession = true;
    _lastAuthError = null;

    final existing = _accountsByEmail[cleanEmail];
    if (existing != null) {
      final updatedProviders = List<String>.from(
        existing.profile.linkedProviders,
      );
      if (!updatedProviders.contains(cleanProvider)) {
        updatedProviders.add(cleanProvider);
      }
      final updatedProfile = existing.profile.copyWith(
        emailVerified: true,
        linkedProviders: updatedProviders,
      );
      _accountsByEmail[cleanEmail] = existing.copyWith(profile: updatedProfile);
      _currentUser = updatedProfile;
      _hasCompletedOnboarding = existing.hasCompletedOnboarding;
    } else {
      final uid = newId();
      final generatedUsername = cleanEmail.contains('@')
          ? cleanEmail.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          : 'athlete_${uid.substring(0, 6)}';
      final profile = UserProfile(
        id: uid,
        email: cleanEmail,
        emailVerified: true,
        username: generatedUsername,
        name: displayName.trim().isEmpty
            ? generatedUsername
            : displayName.trim(),
        linkedProviders: [cleanProvider],
        role: UserRole.user,
        createdAt: DateTime.now(),
      );
      final salt = _generateSalt();
      _accountsByEmail[cleanEmail] = _StoredUserAccount(
        userId: uid,
        email: cleanEmail,
        username: profile.username,
        passwordSalt: salt,
        passwordHash: _hashWithSalt(newId(), salt),
        profile: profile,
        hasCompletedOnboarding: !isFirstTimeUser,
      );
      _currentUser = profile;
      _hasCompletedOnboarding = !isFirstTimeUser;
    }

    _isAuthenticated = true;
    unawaited(_loadUserIsolatedState(_currentUser!.id));
    unawaited(_persistActiveSession());
    notifyListeners();
    return AuthActionResult(
      isSuccess: true,
      message: 'Authenticated with ${cleanProvider.toUpperCase()}.',
    );
  }

  // ============================================================================
  // 6-DIGIT EMAIL OTP VERIFICATION & PASSWORD RECOVERY WORKFLOW
  // (Salted SHA-256 OTP hashes — plaintext OTPs are NEVER stored in state!)
  // ============================================================================
  String? _pendingEmail;
  String? _pendingUsername;
  String? _pendingOtpSalt;
  String? _pendingOtpHash;
  DateTime? _pendingOtpExpiresAt;
  bool _pendingOtpUsed = false;
  int _pendingOtpFailedAttempts = 0;

  String? _recoveryEmail;
  String? _recoveryOtpSalt;
  String? _recoveryOtpHash;
  DateTime? _recoveryOtpExpiresAt;
  bool _recoveryOtpUsed = false;
  int _recoveryOtpFailedAttempts = 0;

  String? get pendingEmail => _pendingEmail;
  String? get pendingUsername => _pendingUsername;
  DateTime? get pendingOtpExpiresAt => _pendingOtpExpiresAt;

  void _clearPendingVerificationState() {
    _pendingEmail = null;
    _pendingUsername = null;
    _pendingOtpSalt = null;
    _pendingOtpHash = null;
    _pendingOtpExpiresAt = null;
    _pendingOtpUsed = false;
    _pendingOtpFailedAttempts = 0;
  }

  /// Masks an email address (e.g. "m***@gmail.com")
  static String maskEmail(String email) {
    final clean = email.trim();
    final parts = clean.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return clean;
    final local = parts[0];
    final domain = parts[1];
    final firstChar = local.substring(0, 1);
    return '$firstChar***@$domain';
  }

  /// Legacy in-memory signup used **only by automated tests**. It never sends
  /// email and must not be called from the UI: production registration goes
  /// through [registerWithEmail] → Supabase Auth.
  @visibleForTesting
  String startPendingEmailRegistration({
    required String username,
    required String email,
    required String password,
    String? deterministicOtpForTesting,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    _isAuthenticated = false;
    _hasCompletedOnboarding = false;
    _lastAuthError = null;
    _pendingEmail = cleanEmail;
    _pendingUsername = cleanUsername;

    final generatedOtp =
        deterministicOtpForTesting ??
        (100000 + _random.nextInt(900000)).toString();
    final otpSalt = _generateSalt();
    _pendingOtpSalt = otpSalt;
    _pendingOtpHash = _hashWithSalt(generatedOtp, otpSalt);
    _pendingOtpExpiresAt = DateTime.now().add(const Duration(minutes: 10));
    _pendingOtpUsed = false;
    _pendingOtpFailedAttempts = 0;

    final pwdSalt = _generateSalt();
    final pwdHash = _hashWithSalt(password, pwdSalt);
    final existing = _accountsByEmail[cleanEmail];
    final userId = existing?.userId ?? newId();

    final unverifiedProfile = UserProfile(
      id: userId,
      email: cleanEmail,
      emailVerified: false,
      username: cleanUsername,
      name: cleanUsername,
      linkedProviders: const ['email'],
      role: UserRole
          .user, // Security rule: new accounts ALWAYS default to UserRole.user
      xpPoints: 0,
      streakDays: 0,
      createdAt: DateTime.now(),
    );

    _accountsByEmail[cleanEmail] = _StoredUserAccount(
      userId: userId,
      email: cleanEmail,
      username: cleanUsername,
      passwordSalt: pwdSalt,
      passwordHash: pwdHash,
      profile: unverifiedProfile,
      hasCompletedOnboarding: false,
    );

    _currentUser = unverifiedProfile;
    _workouts.clear();
    _personalRecords.clear();
    _activeWorkoutDraft = null;

    notifyListeners();
    return generatedOtp;
  }

  /// Generates a fresh 6-digit OTP, invalidating any previous code, and resets the 10-minute expiry.
  /// Legacy test-only flow — production resends use [resendSignupCode].
  @visibleForTesting
  String resendEmailVerificationOtp({String? deterministicOtpForTesting}) {
    final targetEmail =
        (_pendingEmail ?? _currentUser?.email ?? 'athlete@gmail.com')
            .trim()
            .toLowerCase();
    _pendingEmail = targetEmail;
    final generatedOtp =
        deterministicOtpForTesting ??
        (100000 + _random.nextInt(900000)).toString();
    final otpSalt = _generateSalt();
    _pendingOtpSalt = otpSalt;
    _pendingOtpHash = _hashWithSalt(generatedOtp, otpSalt);
    _pendingOtpExpiresAt = DateTime.now().add(const Duration(minutes: 10));
    _pendingOtpUsed = false;
    _pendingOtpFailedAttempts = 0;

    notifyListeners();
    return generatedOtp;
  }

  /// Helper for automated tests to simulate a 10-minute OTP expiration.
  @visibleForTesting
  void expirePendingOtpForTesting() {
    if (_pendingOtpExpiresAt != null) {
      _pendingOtpExpiresAt = DateTime.now().subtract(
        const Duration(minutes: 1),
      );
    }
  }

  /// Validates the entered 6-digit OTP against expiration, rate limits, and SHA-256 hash match.
  /// Legacy test-only flow — production verification uses [verifySignupCode].
  @visibleForTesting
  OtpVerificationResult verifyEmailOtp(String enteredCode) {
    final cleanCode = enteredCode.trim();

    if (_pendingOtpHash == null ||
        _pendingOtpSalt == null ||
        _pendingOtpExpiresAt == null) {
      return const OtpVerificationResult(
        isSuccess: false,
        message: 'This code has expired. Request a new verification code.',
        isExpired: true,
      );
    }

    if (_pendingOtpUsed) {
      return const OtpVerificationResult(
        isSuccess: false,
        message: 'This code has expired. Request a new verification code.',
        isExpired: true,
      );
    }

    if (DateTime.now().isAfter(_pendingOtpExpiresAt!)) {
      return const OtpVerificationResult(
        isSuccess: false,
        message: 'This code has expired. Request a new verification code.',
        isExpired: true,
      );
    }

    if (_pendingOtpFailedAttempts >= 5) {
      return const OtpVerificationResult(
        isSuccess: false,
        message:
            'Too many failed attempts. Please request a new verification code.',
        isRateLimited: true,
      );
    }

    final candidateHash = _hashWithSalt(cleanCode, _pendingOtpSalt!);
    if (candidateHash != _pendingOtpHash) {
      _pendingOtpFailedAttempts++;
      notifyListeners();
      return const OtpVerificationResult(
        isSuccess: false,
        message: 'Incorrect verification code. Please try again.',
      );
    }

    // Code is valid! Prevent reuse, mark email as verified, and unlock First-Time Onboarding
    _pendingOtpUsed = true;
    _pendingOtpHash = null;
    _pendingOtpSalt = null;

    final verifiedEmail = (_pendingEmail ?? _currentUser?.email ?? '')
        .trim()
        .toLowerCase();
    final verifiedUsername =
        _pendingUsername ?? _currentUser?.username ?? 'athlete';

    final verifiedProfile =
        (_currentUser ??
                UserProfile(
                  id: newId(),
                  name: verifiedUsername,
                  role: UserRole.user,
                  createdAt: DateTime.now(),
                ))
            .copyWith(
              email: verifiedEmail,
              emailVerified: true,
              username: verifiedUsername,
              name: verifiedUsername,
              linkedProviders: const ['email'],
            );

    _currentUser = verifiedProfile;
    final existingAccount = _accountsByEmail[verifiedEmail];
    if (existingAccount != null) {
      _accountsByEmail[verifiedEmail] = existingAccount.copyWith(
        profile: verifiedProfile,
      );
    }

    _isAuthenticated = true;
    _hasCompletedOnboarding = false;
    unawaited(_loadUserIsolatedState(verifiedProfile.id));
    unawaited(_persistActiveSession());
    notifyListeners();

    return const OtpVerificationResult(
      isSuccess: true,
      message: 'Email Verified Successfully!',
    );
  }

  /// Initiates Forgot Password recovery by generating a salted SHA-256 6-digit recovery code.
  /// Legacy test-only flow — production uses [sendPasswordResetCode].
  @visibleForTesting
  AuthActionResult requestPasswordRecovery({
    required String email,
    String? deterministicOtpForTesting,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'Enter a valid email address to reset your password.',
      );
    }
    final account = _accountsByEmail[cleanEmail];
    if (account == null) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'No registered account found for that email address.',
      );
    }

    final recoveryCode =
        deterministicOtpForTesting ??
        (100000 + _random.nextInt(900000)).toString();
    final salt = _generateSalt();
    _recoveryEmail = cleanEmail;
    _recoveryOtpSalt = salt;
    _recoveryOtpHash = _hashWithSalt(recoveryCode, salt);
    _recoveryOtpExpiresAt = DateTime.now().add(const Duration(minutes: 10));
    _recoveryOtpUsed = false;
    _recoveryOtpFailedAttempts = 0;

    notifyListeners();
    return AuthActionResult(
      isSuccess: true,
      message:
          'A 6-digit password reset code has been sent to ${maskEmail(cleanEmail)}.',
    );
  }

  /// Completes Password Reset using the 6-digit recovery code and updates the user's password hash.
  /// Legacy test-only flow — production uses [resetPasswordWithCode].
  @visibleForTesting
  AuthActionResult completePasswordReset({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (newPassword.length < 8) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'New password must be at least 8 characters long.',
      );
    }
    if (_recoveryEmail != cleanEmail ||
        _recoveryOtpHash == null ||
        _recoveryOtpSalt == null ||
        _recoveryOtpExpiresAt == null ||
        _recoveryOtpUsed ||
        DateTime.now().isAfter(_recoveryOtpExpiresAt!)) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'Password reset code has expired. Please request a new code.',
      );
    }
    if (_recoveryOtpFailedAttempts >= 5) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'Too many failed recovery attempts. Request a new code.',
      );
    }

    final candidateHash = _hashWithSalt(recoveryCode.trim(), _recoveryOtpSalt!);
    if (candidateHash != _recoveryOtpHash) {
      _recoveryOtpFailedAttempts++;
      return const AuthActionResult(
        isSuccess: false,
        message: 'Invalid password recovery code.',
      );
    }

    final account = _accountsByEmail[cleanEmail];
    if (account == null) {
      return const AuthActionResult(
        isSuccess: false,
        message: 'Account not found.',
      );
    }

    _recoveryOtpUsed = true;
    _recoveryOtpHash = null;
    _recoveryOtpSalt = null;

    final newSalt = _generateSalt();
    final newHash = _hashWithSalt(newPassword, newSalt);
    _accountsByEmail[cleanEmail] = account.copyWith(
      passwordSalt: newSalt,
      passwordHash: newHash,
    );

    // Invalidate existing session so user signs in with the new password
    _isAuthenticated = false;
    unawaited(SecureSessionStorage.instance.clearActiveSession());
    notifyListeners();
    return const AuthActionResult(
      isSuccess: true,
      message: 'Password updated successfully. You can now log in.',
    );
  }

  // Email delivery is owned by Supabase Auth + the configured SMTP provider.
  // The client never builds or sends verification emails itself.

  void registerAccount({
    required String email,
    required String username,
    required String name,
    String password = 'ChangeMe123!',
    String experienceLevel = 'Intermediate',
    String trainingInterest = 'Hybrid Training',
    String? tiktokUsername,
    bool startOnboarding = true,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final uid = newId();
    final profile = UserProfile(
      id: uid,
      email: cleanEmail,
      emailVerified: true,
      username: username.trim(),
      name: name.trim(),
      experienceLevel: experienceLevel,
      trainingInterest: trainingInterest,
      linkedProviders: const ['email'],
      tiktokUsername: tiktokUsername,
      role: UserRole
          .user, // Security rule: never default new registrations to Owner
      xpPoints: 0,
      streakDays: 0,
      createdAt: DateTime.now(),
    );
    final salt = _generateSalt();
    _accountsByEmail[cleanEmail] = _StoredUserAccount(
      userId: uid,
      email: cleanEmail,
      username: profile.username,
      passwordSalt: salt,
      passwordHash: _hashWithSalt(password, salt),
      profile: profile,
      hasCompletedOnboarding: !startOnboarding,
    );
    _currentUser = profile;
    _isAuthenticated = true;
    _hasCompletedOnboarding = !startOnboarding;
    unawaited(_loadUserIsolatedState(uid));
    unawaited(_persistActiveSession());
    notifyListeners();
  }

  void completeOnboarding({
    required String experienceLevel,
    required String trainingInterest,
    String workoutFrequency = '4 days per week',
    required List<String> preferredDays,
    required List<String> goals,
    String units = 'metric',
    String? username,
    String? tiktokUsername,
  }) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        experienceLevel: experienceLevel,
        trainingInterest: trainingInterest,
        workoutFrequency: workoutFrequency,
        preferredDays: preferredDays,
        trainingGoals: goals,
        units: units,
        username: (username != null && username.trim().isNotEmpty)
            ? username.trim()
            : _currentUser!.username,
        tiktokUsername: tiktokUsername ?? _currentUser!.tiktokUsername,
      );
    }
    _hasCompletedOnboarding = true;
    unawaited(_saveCurrentUserIsolatedState());
    unawaited(_persistActiveSession());
    _syncCurrentUserLeaderboardEntry();
    notifyListeners();
  }

  String linkIdentityProvider(String provider) {
    if (_currentUser == null) return 'Not signed in.';
    final list = List<String>.from(_currentUser!.linkedProviders);
    if (list.contains(provider)) {
      return '${provider.toUpperCase()} is already linked to your account.';
    }
    list.add(provider);
    _currentUser = _currentUser!.copyWith(linkedProviders: list);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: _currentUser!.id,
        actorName: _currentUser!.name,
        actorRole: _currentUser!.role,
        action: 'LINKED_AUTH_PROVIDER',
        targetTitle: provider.toUpperCase(),
        details: 'Connected $provider OAuth identity to existing account.',
        timestamp: DateTime.now(),
      ),
    );
    unawaited(_saveCurrentUserIsolatedState());
    notifyListeners();
    return 'Successfully linked ${provider.toUpperCase()} to your Lifting Life account.';
  }

  String unlinkIdentityProvider(String provider) {
    if (_currentUser == null) return 'Not signed in.';
    final list = List<String>.from(_currentUser!.linkedProviders);
    if (list.length <= 1) {
      return 'Security Guard: You must keep at least one active login method linked to prevent account lockout.';
    }
    list.remove(provider);
    _currentUser = _currentUser!.copyWith(linkedProviders: list);
    unawaited(_saveCurrentUserIsolatedState());
    notifyListeners();
    return 'Unlinked ${provider.toUpperCase()} from your account.';
  }

  void changeAccountEmail(String newEmail) {
    if (_currentUser == null || newEmail.trim().isEmpty) return;
    final oldKey = _currentUser!.email.trim().toLowerCase();
    final newKey = newEmail.trim().toLowerCase();
    _currentUser = _currentUser!.copyWith(email: newKey);
    final acc = _accountsByEmail.remove(oldKey);
    if (acc != null) {
      _accountsByEmail[newKey] = acc.copyWith(
        email: newKey,
        profile: _currentUser!,
      );
    }
    unawaited(_saveCurrentUserIsolatedState());
    unawaited(_persistActiveSession());
    notifyListeners();
  }

  void signOut() {
    unawaited(_saveCurrentUserIsolatedState());
    unawaited(emailAuthBackend.signOut());
    unawaited(SecureSessionStorage.instance.clearActiveSession());
    _isAuthenticated = false;
    _hasCompletedOnboarding = false;
    _isDemo = false;
    _currentUser = null;
    _workouts.clear();
    _personalRecords.clear();
    _activeWorkoutDraft = null;
    notifyListeners();
  }

  /// Owner-only role assignment enforcing Task 6 security rules.
  /// Regular users and admins cannot self-promote or assign the Owner role.
  String assignUserRole({
    required String targetUserId,
    required UserRole newRole,
  }) {
    final actor = _currentUser;
    if (actor == null || actor.role != UserRole.owner) {
      _auditLogs.insert(
        0,
        AdminAuditLog(
          id: newId(),
          actorId: actor?.id ?? 'unauthenticated',
          actorName: actor?.name ?? 'Anonymous',
          actorRole: actor?.role ?? UserRole.user,
          action: 'UNAUTHORIZED_ROLE_ASSIGNMENT_ATTEMPT',
          targetTitle: targetUserId,
          details:
              'Blocked attempt to assign role ${newRole.label} without Owner authority.',
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return 'Unauthorized: Only the App Owner can assign or elevate user roles.';
    }

    for (final entry in _accountsByEmail.entries) {
      if (entry.value.userId == targetUserId) {
        final updatedProfile = entry.value.profile.copyWith(role: newRole);
        _accountsByEmail[entry.key] = entry.value.copyWith(
          profile: updatedProfile,
        );
        if (_currentUser?.id == targetUserId) {
          _currentUser = updatedProfile;
        }
        break;
      }
    }

    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: actor.id,
        actorName: actor.name,
        actorRole: actor.role,
        action: 'ASSIGNED_USER_ROLE',
        targetTitle: targetUserId,
        details: 'Assigned role ${newRole.label} by App Owner.',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
    return 'Assigned role ${newRole.label}.';
  }

  @visibleForTesting
  void switchActiveRoleForTesting(UserRole newRole) {
    if (!kDebugMode) {
      return;
    }
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(role: newRole);
    final emailKey = _currentUser!.email.trim().toLowerCase();
    final existing = _accountsByEmail[emailKey];
    if (existing != null) {
      _accountsByEmail[emailKey] = existing.copyWith(profile: _currentUser!);
    }
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: _currentUser!.id,
        actorName: _currentUser!.name,
        actorRole: newRole,
        action: 'ROLE_SWITCH_TEST_ONLY',
        targetTitle: _currentUser!.username,
        details: 'Switched test RBAC context to ${newRole.label}',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void updateProfile(UserProfile updated) {
    // Prevent privilege escalation through profile update
    final safeRole = _currentUser?.role ?? UserRole.user;
    _currentUser = updated.copyWith(role: safeRole);
    _syncCurrentUserLeaderboardEntry();
    unawaited(_saveCurrentUserIsolatedState());
    unawaited(_persistActiveSession());
    notifyListeners();
  }

  String exportUserDataJson() {
    final map = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Lifting Life',
      'profile': _currentUser?.toMap(),
      'workouts': _workouts.map((w) => w.toMap()).toList(),
      'personalRecords': _personalRecords.map((pr) => pr.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  void deleteAccount() {
    final user = _currentUser;
    if (user != null) {
      final emailKey = user.email.trim().toLowerCase();
      _accountsByEmail.remove(emailKey);
      _workoutsByUser.remove(user.id);
      _prsByUser.remove(user.id);
      _draftByUser.remove(user.id);
      _enrolledCourseIdsByUser.remove(user.id);
      _completedLessonsByUser.remove(user.id);
      _leaderboardEntries.removeWhere((e) => e.userId == user.id);
      unawaited(
        SecureSessionStorage.instance.purgeAllDataForDeletedUser(user.id),
      );
    }
    unawaited(SecureSessionStorage.instance.clearActiveSession());
    _workouts.clear();
    _personalRecords.clear();
    _activeWorkoutDraft = null;
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // ============================================================================
  // EXERCISE LIBRARY ACTIONS & AI AGENT 2 CONTRACT IMPLEMENTATION
  // ============================================================================
  void toggleFavoriteExercise(String exerciseId) {
    if (_favoriteExerciseIds.contains(exerciseId)) {
      _favoriteExerciseIds.remove(exerciseId);
    } else {
      _favoriteExerciseIds.add(exerciseId);
    }
    notifyListeners();
  }

  Exercise findExerciseByNameOrDefault(String name) {
    final lower = name.toLowerCase();
    for (final ex in _exercises) {
      if (ex.name.toLowerCase() == lower ||
          ex.name.toLowerCase().contains(lower)) {
        return ex;
      }
    }
    return _exercises.first;
  }

  void addNewExerciseAsAdmin(Exercise exercise) {
    if (_currentUser == null || !_currentUser!.role.canApproveCourses) {
      return;
    }
    _exercises.insert(0, exercise);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: _currentUser!.id,
        actorName: _currentUser!.name,
        actorRole: _currentUser!.role,
        action: 'ADDED_EXERCISE',
        targetTitle: exercise.name,
        details:
            'Added ${exercise.category} (${exercise.equipment}) to master library.',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<List<Exercise>> fetchExercises({
    String? category,
    String? equipment,
    String? searchQuery,
  }) async {
    return _exercises
        .where((ex) {
          if (category != null &&
              category.isNotEmpty &&
              ex.category.toLowerCase() != category.toLowerCase()) {
            return false;
          }
          if (equipment != null &&
              equipment.isNotEmpty &&
              ex.equipment.toLowerCase() != equipment.toLowerCase()) {
            return false;
          }
          if (searchQuery != null &&
              searchQuery.isNotEmpty &&
              !ex.name.toLowerCase().contains(searchQuery.toLowerCase())) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<Exercise?> fetchExerciseById(String exerciseId) async {
    for (final ex in _exercises) {
      if (ex.id == exerciseId) return ex;
    }
    return null;
  }

  @override
  Future<ExerciseVideoAssetDescriptor> fetchExerciseVideoAsset({
    required String exerciseId,
    String? videoId,
  }) async {
    final resolvedVideoId = videoId ?? '${exerciseId}_front';
    final objectPath = CloudStorageService.buildExerciseVideoPath(
      exerciseId: exerciseId,
      videoId: resolvedVideoId,
    );
    final signed = await CloudStorageService.instance.createAuthorizedSignedUrl(
      bucket: StorageBucket.exerciseVideos,
      objectPath: objectPath,
      requestingUserId: _currentUser?.id ?? 'authenticated_client',
      requestingRole: _currentUser?.role ?? UserRole.user,
    );
    return ExerciseVideoAssetDescriptor(
      mediaAssetId: 'vid_$resolvedVideoId',
      exerciseId: exerciseId,
      videoId: resolvedVideoId,
      storageObjectPath: objectPath,
      signedMediaUrl: signed,
    );
  }

  @override
  Future<AnatomyModelAssetDescriptor> fetchAnatomyModelAsset({
    required String exerciseId,
    String modelId = 'lifting_life_anatomy',
    String version = 'v1',
  }) async {
    final ex = _exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => _exercises.first,
    );
    final objectPath = CloudStorageService.buildAnatomyModelPath(
      modelId: modelId,
      version: version,
    );
    final signed = await CloudStorageService.instance.createAuthorizedSignedUrl(
      bucket: StorageBucket.anatomyModels,
      objectPath: objectPath,
      requestingUserId: _currentUser?.id ?? 'authenticated_client',
      requestingRole: _currentUser?.role ?? UserRole.user,
    );
    return AnatomyModelAssetDescriptor(
      mediaAssetId: 'anat_${modelId}_$version',
      modelId: modelId,
      version: version,
      storageObjectPath: objectPath,
      localFallbackAssetPath: ex.glbAssetPath ?? 'assets/models/anatomy_v1.glb',
      signedMediaUrl: signed,
      primaryMuscles: ex.primaryMuscles,
      secondaryMuscles: ex.secondaryMuscles,
    );
  }

  @override
  Future<EquipmentAndMachineAssetDescriptor> fetchEquipmentAndMachineAssets({
    required String exerciseId,
    String version = 'v1',
  }) async {
    final ex = _exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => _exercises.first,
    );
    final equipmentId = Agent2ExerciseAnd3DContract.resolveStableEquipmentId(
      ex.equipment,
    );
    final machineId = Agent2ExerciseAnd3DContract.resolveStableMachineId(ex);
    final eqPath = CloudStorageService.buildEquipmentModelPath(
      equipmentId: equipmentId,
      version: version,
    );
    final eqSigned = await CloudStorageService.instance
        .createAuthorizedSignedUrl(
          bucket: StorageBucket.exerciseEquipment,
          objectPath: eqPath,
          requestingUserId: _currentUser?.id ?? 'authenticated_client',
          requestingRole: _currentUser?.role ?? UserRole.user,
        );
    String? machinePath;
    SignedMediaUrl? machineSigned;
    if (machineId != null) {
      machinePath = CloudStorageService.buildMachineModelPath(
        machineId: machineId,
        version: version,
      );
      machineSigned = await CloudStorageService.instance
          .createAuthorizedSignedUrl(
            bucket: StorageBucket.machineModels,
            objectPath: machinePath,
            requestingUserId: _currentUser?.id ?? 'authenticated_client',
            requestingRole: _currentUser?.role ?? UserRole.user,
          );
    }
    return EquipmentAndMachineAssetDescriptor(
      mediaAssetId: 'eq_${equipmentId}_$version',
      exerciseId: exerciseId,
      equipmentId: equipmentId,
      machineId: machineId,
      version: version,
      equipmentObjectPath: eqPath,
      machineObjectPath: machinePath,
      equipmentSignedUrl: eqSigned,
      machineSignedUrl: machineSigned,
    );
  }

  @override
  Future<WorkoutSaveReceipt> saveWorkoutData({
    required Workout workout,
    String? clientIdempotencyKey,
  }) async {
    final beforePrs = _personalRecords.length;
    final msg = addWorkout(workout);
    final afterPrs = _personalRecords.length;
    return WorkoutSaveReceipt(
      isSuccess: !msg.startsWith('Blocked'),
      workoutId: workout.id,
      userId: _currentUser?.id ?? workout.userId,
      idempotencyKey: clientIdempotencyKey ?? workout.id,
      unlockedPrCount: (afterPrs - beforePrs).clamp(0, 100),
      statusMessage: msg,
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Workout>> fetchWorkoutHistory({int limit = 50}) async {
    final sorted = List<Workout>.from(_workouts)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<List<PersonalRecord>> fetchPersonalRecords({
    String? exerciseId,
  }) async {
    if (exerciseId == null || exerciseId.trim().isEmpty) {
      return List<PersonalRecord>.unmodifiable(_personalRecords);
    }
    final ex = await fetchExerciseById(exerciseId);
    final q = (ex?.name ?? exerciseId).trim().toLowerCase();
    return _personalRecords
        .where((pr) => pr.exerciseName.toLowerCase() == q)
        .toList(growable: false);
  }

  // ============================================================================
  // WORKOUT LOGGING, ACTIVE DRAFT PERSISTENCE & ANTI-CHEAT XP REWARDS
  // ============================================================================
  @override
  Future<void> saveActiveWorkoutDraft(Workout? draft) async {
    final user = _currentUser;
    if (user == null || !_isAuthenticated) return;
    if (draft != null && draft.userId != user.id) {
      throw StateError('Cannot save a workout for another user.');
    }
    _activeWorkoutDraft = draft;
    _draftByUser[user.id] = draft;
    notifyListeners();
    // Draft edits do not require rewriting profile, history and PRs.
    await SecureSessionStorage.instance.saveUserScopedJson(
      userId: user.id, collection: 'active_draft',
      jsonEncodable: {'draft': draft?.toMap()},
    );
  }

  void _syncCurrentUserLeaderboardEntry() {
    final user = _currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weeklySessions = _workouts
        .where(
          (w) => !w.date.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
          ),
        )
        .length;
    final completedCoursesCount = _courses
        .where(
          (c) =>
              c.isEnrolled &&
              c.lessons.isNotEmpty &&
              c.completedLessonIds.length >= c.lessons.length,
        )
        .length;

    final sbd = currentUserSbdTotalKg;
    final bw = (user.weight != null && user.weight! > 30) ? user.weight! : 80.0;
    final strengthIndex = sbd > 0 ? (sbd / bw) * 25.0 : 0.0;

    final prSummary = _personalRecords.isEmpty
        ? 'No PRs logged yet'
        : _personalRecords
              .take(3)
              .map(
                (pr) =>
                    '${pr.category}: ${pr.weightKg.toStringAsFixed(1)} kg × ${pr.reps}',
              )
              .join(' • ');

    final entry = LeaderboardEntry(
      userId: user.id,
      username: user.username,
      displayName: '${user.name} (You)',
      tiktokHandle: user.tiktokUsername,
      xpPoints: user.xpPoints,
      weeklySessionsCompleted: weeklySessions,
      streakDays: user.streakDays,
      coursesCompleted: completedCoursesCount,
      powerliftingStrengthIndex: strengthIndex,
      bestPrSummary: prSummary,
      hidePersonalRecords: user.hidePersonalRecords,
      rankDelta: 0,
      isFriend: true,
      experienceLevel: user.experienceLevel,
      trainingInterest: user.trainingInterest,
    );

    final idx = _leaderboardEntries.indexWhere((e) => e.userId == user.id);
    if (idx != -1) {
      _leaderboardEntries[idx] = entry;
    } else if (_workouts.isNotEmpty || user.xpPoints > 0) {
      _leaderboardEntries.add(entry);
    }
    _sortLeaderboard();
  }

  String addWorkout(Workout workout) {
    if (!_isAuthenticated || _currentUser == null || workout.userId != _currentUser!.id) {
      return 'Please sign in to save your own workout.';
    }
    if (workout.completedSets == 0) return 'Complete at least one set before saving.';
    // Idempotency guard: prevent duplicate workout submission
    if (_workouts.any((w) => w.id == workout.id)) {
      return 'Workout already saved.';
    }

    // Anti-spam / anti-fraud check: reject impossible weights (>600 kg single lift)
    for (final ex in workout.exercises) {
      for (final s in ex.sets) {
        if (!(s.weight ?? 0).isFinite || (s.weight ?? 0) < 0 ||
            (s.reps ?? 0) < 0 || (s.weight ?? 0) > 600 || (s.reps ?? 0) > 250) {
          return 'Blocked by Anti-Cheat: Unrealistic load or repetition count detected.';
        }
      }
    }

    final ownerId = _currentUser?.id ?? workout.userId;
    final normalizedWorkout = Workout(
      id: workout.id,
      userId: ownerId,
      name: workout.name,
      trainingMode: workout.trainingMode,
      exercises: workout.exercises,
      date: workout.date,
      durationMinutes: workout.durationMinutes,
      notes: workout.notes,
      isTemplate: workout.isTemplate,
      createdAt: workout.createdAt,
    );

    _workouts.add(normalizedWorkout);
    _activeWorkoutDraft = null;
    _isDemo = false;

    // Detect new Personal Records
    int newPrCount = 0;
    for (final ex in normalizedWorkout.exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted &&
            !s.isWarmup &&
            (s.weight ?? 0) > 0 &&
            (s.reps ?? 0) > 0) {
          final e1rm = s.estimatedOneRepMax;
          final existingBest = _personalRecords
              .where(
                (pr) => pr.exerciseName.toLowerCase() == ex.name.toLowerCase(),
              )
              .fold<double>(
                0,
                (prev, pr) => pr.estimated1RM > prev ? pr.estimated1RM : prev,
              );

          if (e1rm > existingBest) {
            newPrCount++;
            String cat = 'General';
            if (ex.name.toLowerCase().contains('squat')) cat = 'Squat';
            if (ex.name.toLowerCase().contains('bench')) cat = 'Bench Press';
            if (ex.name.toLowerCase().contains('deadlift')) cat = 'Deadlift';

            _personalRecords.add(
              PersonalRecord(
                id: newId(),
                exerciseName: ex.name,
                category: cat,
                weightKg: s.weight!,
                reps: s.reps!,
                estimated1RM: e1rm,
                date: normalizedWorkout.date,
                isCompetitionLift: cat != 'General',
              ),
            );
          }
        }
      }
    }

    // Frequency-capped XP reward (Cap at 5 workouts per week so excessive exercise gives no unfair advantage)
    if (_currentUser != null) {
      final idx = _leaderboardEntries.indexWhere(
        (e) => e.userId == _currentUser!.id,
      );
      final currentWeekly = idx != -1
          ? _leaderboardEntries[idx].weeklySessionsCompleted
          : 0;
      int xpEarned = 0;
      if (currentWeekly < 5) {
        xpEarned += 150; // Base session consistency reward
      }
      xpEarned += newPrCount * 50;

      _currentUser = _currentUser!.copyWith(
        xpPoints: _currentUser!.xpPoints + xpEarned,
        streakDays: _currentUser!.streakDays + 1,
      );

      _syncCurrentUserLeaderboardEntry();
      unawaited(_saveCurrentUserIsolatedState());
    }

    notifyListeners();
    return newPrCount > 0
        ? 'Workout logged! +$newPrCount Personal Record(s) unlocked!'
        : 'Workout logged! Consistency streak updated.';
  }

  void saveWorkoutTemplate(Workout template) {
    _workoutTemplates.insert(0, template.copyWith(isTemplate: true));
    notifyListeners();
  }

  void addCustomProgram(TrainingProgram program) {
    _programs.insert(0, program);
    notifyListeners();
  }

  void _sortLeaderboard() {
    _leaderboardEntries.sort((a, b) => b.xpPoints.compareTo(a.xpPoints));
  }

  // ============================================================================
  // SOCIAL FEED, FRIENDS & LEADERBOARD ACTIONS
  // ============================================================================
  void createSocialPost({
    required String caption,
    required String postType,
    required String exerciseName,
    String? prHighlight,
  }) {
    if (_currentUser == null) return;
    final ex = findExerciseByNameOrDefault(exerciseName);
    _socialPosts.insert(
      0,
      SocialPost(
        id: newId(),
        authorId: _currentUser!.id,
        authorUsername: _currentUser!.username,
        authorName: _currentUser!.name,
        authorRoleBadge: _currentUser!.role.label,
        tiktokHandle: _currentUser!.tiktokUsername,
        caption: caption,
        postType: postType,
        exerciseName: ex.name,
        movementPattern: ex.movementPattern,
        prHighlight: prHighlight,
        likesCount: 1,
        isLikedByMe: true,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void toggleLikePost(String postId) {
    final idx = _socialPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final p = _socialPosts[idx];
    final liked = !p.isLikedByMe;
    _socialPosts[idx] = p.copyWith(
      isLikedByMe: liked,
      likesCount: liked ? p.likesCount + 1 : p.likesCount - 1,
    );
    notifyListeners();
  }

  void toggleSavePost(String postId) {
    final idx = _socialPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final p = _socialPosts[idx];
    _socialPosts[idx] = p.copyWith(isSavedByMe: !p.isSavedByMe);
    notifyListeners();
  }

  void addCommentToPost(String postId, String text) {
    if (text.trim().isEmpty || _currentUser == null) return;
    final idx = _socialPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final p = _socialPosts[idx];
    final updatedComments = List<PostComment>.from(p.comments)
      ..add(
        PostComment(
          id: newId(),
          authorUsername: _currentUser!.username,
          text: text.trim(),
          createdAt: DateTime.now(),
        ),
      );
    _socialPosts[idx] = p.copyWith(comments: updatedComments);
    notifyListeners();
  }

  void reportContent({
    required String targetType,
    required String targetId,
    required String targetSummary,
    required String reason,
  }) {
    _reports.insert(
      0,
      AbuseReport(
        id: newId(),
        reporterUsername: _currentUser?.username ?? 'anonymous',
        targetType: targetType,
        targetId: targetId,
        targetSummary: targetSummary,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void blockUser(String targetUserId) {
    if (_currentUser == null) return;
    final updatedBlocked = List<String>.from(_currentUser!.blockedUserIds);
    if (!updatedBlocked.contains(targetUserId)) {
      updatedBlocked.add(targetUserId);
      _currentUser = _currentUser!.copyWith(blockedUserIds: updatedBlocked);
      notifyListeners();
    }
  }

  void toggleFriendConnection(String userId) {
    final idx = _leaderboardEntries.indexWhere((e) => e.userId == userId);
    if (idx != -1) {
      final current = _leaderboardEntries[idx];
      _leaderboardEntries[idx] = current.copyWith(isFriend: !current.isFriend);
      notifyListeners();
    }
  }

  String addFriendByUsernameOrTikTok(String query) {
    final clean = query.trim().replaceAll('@', '').toLowerCase();
    if (clean.isEmpty) return 'Enter a valid username.';

    final existingIdx = _leaderboardEntries.indexWhere(
      (e) =>
          e.username.toLowerCase() == clean ||
          (e.tiktokHandle?.replaceAll('@', '').toLowerCase() == clean),
    );
    if (existingIdx != -1) {
      _leaderboardEntries[existingIdx] = _leaderboardEntries[existingIdx]
          .copyWith(isFriend: true);
      notifyListeners();
      return 'Connected with @$clean!';
    }

    // Look up registered real accounts in the database
    for (final acc in _accountsByEmail.values) {
      final uname = acc.username.toLowerCase();
      final tk =
          acc.profile.tiktokUsername?.replaceAll('@', '').toLowerCase() ?? '';
      if (uname == clean || (tk.isNotEmpty && tk == clean)) {
        if (acc.userId == _currentUser?.id) {
          return 'You cannot add yourself as a friend.';
        }
        _leaderboardEntries.add(
          LeaderboardEntry(
            userId: acc.userId,
            username: acc.profile.username,
            displayName: acc.profile.name,
            tiktokHandle: acc.profile.tiktokUsername,
            xpPoints: acc.profile.xpPoints,
            weeklySessionsCompleted:
                (_workoutsByUser[acc.userId] ?? const []).length,
            streakDays: acc.profile.streakDays,
            coursesCompleted: 0,
            powerliftingStrengthIndex: 0.0,
            bestPrSummary: 'No PRs logged yet',
            isFriend: true,
            experienceLevel: acc.profile.experienceLevel,
            trainingInterest: acc.profile.trainingInterest,
          ),
        );
        _sortLeaderboard();
        notifyListeners();
        return 'Friend added: @${acc.profile.username}';
      }
    }

    return 'No registered athlete found with username "@$clean".';
  }

  void toggleChallengeParticipation(String challengeId) {
    final idx = _challenges.indexWhere((c) => c.id == challengeId);
    if (idx == -1) return;
    final c = _challenges[idx];
    final joined = !c.isJoined;
    _challenges[idx] = c.copyWith(
      isJoined: joined,
      participantsCount: joined
          ? c.participantsCount + 1
          : c.participantsCount - 1,
    );
    notifyListeners();
  }

  // ============================================================================
  // FITNESS COURSES & MANDATORY APP-OWNER APPROVAL WORKFLOW
  // ============================================================================
  List<FitnessCourse> get publiclyApprovedCourses => _courses
      .where((c) => c.status == CourseStatus.approved)
      .toList(growable: false);

  List<FitnessCourse> get enrolledCourses =>
      _courses.where((c) => c.isEnrolled).toList(growable: false);

  void enrollInCourse(String courseId) {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return;
    final c = _courses[idx];
    _courses[idx] = c.copyWith(
      isEnrolled: true,
      enrolledCount: c.isEnrolled ? c.enrolledCount : c.enrolledCount + 1,
    );
    if (_currentUser != null) {
      final set = _enrolledCourseIdsByUser.putIfAbsent(
        _currentUser!.id,
        () => <String>{},
      );
      set.add(courseId);
    }
    notifyListeners();
  }

  void markLessonCompleted(String courseId, String lessonId) {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return;
    final c = _courses[idx];
    final updatedSet = Set<String>.from(c.completedLessonIds)..add(lessonId);
    _courses[idx] = c.copyWith(
      isEnrolled: true,
      completedLessonIds: updatedSet,
    );
    if (_currentUser != null) {
      final uid = _currentUser!.id;
      _enrolledCourseIdsByUser.putIfAbsent(uid, () => <String>{}).add(courseId);
      final map = _completedLessonsByUser.putIfAbsent(
        uid,
        () => <String, Set<String>>{},
      );
      map[courseId] = updatedSet;
      _currentUser = _currentUser!.copyWith(
        xpPoints: _currentUser!.xpPoints + 75,
      );
      _syncCurrentUserLeaderboardEntry();
      unawaited(_saveCurrentUserIsolatedState());
    }
    notifyListeners();
  }

  void addCourseReview({
    required String courseId,
    required int rating,
    required String comment,
  }) {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1 || _currentUser == null) return;
    final c = _courses[idx];
    final updatedReviews = List<CourseReview>.from(c.reviews)
      ..insert(
        0,
        CourseReview(
          id: newId(),
          username: _currentUser!.username,
          rating: rating,
          comment: comment,
          createdAt: DateTime.now(),
        ),
      );
    final avg =
        updatedReviews.fold<double>(0, (s, r) => s + r.rating) /
        updatedReviews.length;
    _courses[idx] = c.copyWith(reviews: updatedReviews, rating: avg);
    notifyListeners();
  }

  /// Creates a course as Draft or submits directly to Pending Review.
  /// No community-created course can EVER be published directly as Approved!
  FitnessCourse submitOrSaveCourse({
    String? existingCourseId,
    required String title,
    required String description,
    required String category,
    required String difficulty,
    required List<CourseLesson> lessons,
    required bool submitForApproval,
  }) {
    final user = _currentUser!;
    final targetStatus = submitForApproval
        ? CourseStatus.pendingReview
        : CourseStatus.draft;

    if (existingCourseId != null) {
      final idx = _courses.indexWhere((c) => c.id == existingCourseId);
      if (idx != -1) {
        final old = _courses[idx];
        // Rule 12: Material changes to an approved course require Owner review again!
        final effectiveStatus = old.status == CourseStatus.approved
            ? CourseStatus.pendingReview
            : targetStatus;

        final updated = old.copyWith(
          title: title,
          description: description,
          category: category,
          difficulty: difficulty,
          lessons: lessons,
          status: effectiveStatus,
          updatedAt: DateTime.now(),
        );
        _courses[idx] = updated;
        notifyListeners();
        return updated;
      }
    }

    final newCourse = FitnessCourse(
      id: newId(),
      title: title,
      description: description,
      category: category,
      difficulty: difficulty,
      creatorId: user.id,
      creatorName: user.name,
      creatorCredentials: '${user.role.label} • ${user.experienceLevel}',
      status: targetStatus,
      rating: 0.0,
      enrolledCount: 0,
      lessons: lessons,
      updatedAt: DateTime.now(),
    );

    _courses.insert(0, newCourse);

    if (submitForApproval) {
      _notifications.insert(
        0,
        AppNotification(
          id: newId(),
          title: 'New Course Submitted for Owner Approval',
          body:
              '"$title" by ${user.name} is now Pending Review in the Admin Dashboard.',
          category: 'course',
          createdAt: DateTime.now(),
        ),
      );
    }

    notifyListeners();
    return newCourse;
  }

  /// Enforces backend RBAC rules:
  /// 1. Only Owner or Admin can approve/reject/request changes.
  /// 2. Creators (unless they are the App Owner) cannot approve their own courses.
  String reviewCourseSubmission({
    required String courseId,
    required CourseStatus decision,
    required String feedback,
  }) {
    final actor = _currentUser;
    if (actor == null || !actor.role.canApproveCourses) {
      return 'Unauthorized: Only the App Owner or an authorized Administrator can review course submissions.';
    }

    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return 'Course not found.';

    final course = _courses[idx];
    if (course.creatorId == actor.id && actor.role != UserRole.owner) {
      return 'Security Policy Violation: Course creators cannot approve their own courses.';
    }

    _courses[idx] = course.copyWith(
      status: decision,
      reviewerFeedback: feedback.trim().isEmpty
          ? (decision == CourseStatus.approved
                ? 'Approved by Owner for public catalog.'
                : 'Reviewed by Admin.')
          : feedback.trim(),
      approvedByOwnerName: decision == CourseStatus.approved
          ? '${actor.name} (${actor.role.label})'
          : null,
      approvedAt: decision == CourseStatus.approved ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );

    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: actor.id,
        actorName: actor.name,
        actorRole: actor.role,
        action: 'COURSE_${decision.name.toUpperCase()}',
        targetTitle: course.title,
        details: feedback.trim().isEmpty
            ? 'Status set to ${decision.label}'
            : feedback.trim(),
        timestamp: DateTime.now(),
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: newId(),
        title: 'Course Review Decision: ${decision.label}',
        body: '"${course.title}" status updated to ${decision.label}.',
        category: 'course',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    return 'Course "${course.title}" marked as ${decision.label}.';
  }

  void resolveAbuseReport(String reportId, String resolution) {
    if (_currentUser == null || !_currentUser!.role.canApproveCourses) {
      return;
    }
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx == -1) return;
    _reports[idx] = _reports[idx].copyWith(status: resolution);
    _auditLogs.insert(
      0,
      AdminAuditLog(
        id: newId(),
        actorId: _currentUser!.id,
        actorName: _currentUser!.name,
        actorRole: _currentUser!.role,
        action: 'REPORT_${resolution.toUpperCase()}',
        targetTitle: _reports[idx].targetSummary,
        details: 'Moderation resolution: $resolution',
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  // Legacy helpers for Nutrition / Date queries
  List<MealEntry> getMealsForDate(DateTime date) {
    return _meals.where((meal) {
      return meal.date.year == date.year &&
          meal.date.month == date.month &&
          meal.date.day == date.day;
    }).toList();
  }

  List<Workout> getWorkoutsForDate(DateTime date) {
    return _workouts.where((workout) {
      return workout.date.year == date.year &&
          workout.date.month == date.month &&
          workout.date.day == date.day;
    }).toList();
  }

  void addMeal(MealEntry meal) {
    _meals.add(meal);
    _isDemo = false;
    notifyListeners();
  }

  void deleteMeal(String mealId) {
    _meals.removeWhere((m) => m.id == mealId);
    _isDemo = false;
    notifyListeners();
  }

  void updateNutritionTargets(NutritionTargets targets) {
    _nutritionTargets = targets;
    _isDemo = false;
    notifyListeners();
  }

  void addCustomFood(FoodItem food) {
    _customFoods.add(food);
    _isDemo = false;
    notifyListeners();
  }

  void addGoal(Goal goal) {
    _goals.add(goal);
    _isDemo = false;
    notifyListeners();
  }

  void updateGoal(String goalId, double newCurrent) {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = Goal(
        id: _goals[index].id,
        userId: _goals[index].userId,
        type: _goals[index].type,
        target: _goals[index].target,
        current: newCurrent,
        unit: _goals[index].unit,
        createdAt: _goals[index].createdAt,
        deadline: _goals[index].deadline,
      );
      _isDemo = false;
      notifyListeners();
    }
  }
}
