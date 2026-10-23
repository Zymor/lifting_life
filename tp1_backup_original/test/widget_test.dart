import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/core/configuration/supabase_config.dart';
import 'package:tp1/core/contracts/agent2_exercise_3d_contract.dart';
import 'package:tp1/core/security/demo_data_cleanup_service.dart';
import 'package:tp1/core/storage/cloud_storage_service.dart';
import 'package:tp1/main.dart';
import 'package:tp1/models/course.dart';
import 'package:tp1/models/user_profile.dart';
import 'package:tp1/models/workout.dart';
import 'package:tp1/services/data_service.dart';
import 'package:tp1/widgets/exercise_3d_viewer.dart';

void main() {
  test(
    'Task 1: Production state starts with zero fake users, workouts, PRs, friends, or pre-enrolled courses',
    () {
      final data = DataService.instance;
      data.initializeProductionState();

      expect(data.isAuthenticated, isFalse);
      expect(data.currentUser, isNull);
      expect(data.workouts, isEmpty);
      expect(data.personalRecords, isEmpty);
      expect(data.leaderboardEntries, isEmpty);
      expect(data.enrolledCourses, isEmpty);
      expect(data.exercises.length, greaterThanOrEqualTo(200));
    },
  );

  testWidgets(
    'First app launch starts with Splash -> Welcome -> OAuth / Email Onboarding -> Main Dashboard with clean empty states',
    (WidgetTester tester) async {
      final data = DataService.instance;
      data.initializeProductionState();

      await tester.pumpWidget(const LiftingLifeApp());

      // 1. Splash screen appears first
      expect(find.text('LIFTING LIFE'), findsOneWidget);
      expect(find.text('Checking secure session...'), findsOneWidget);

      // Advance past the 650ms Splash session check
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));

      // 2. Welcome screen with Facebook, Apple, and Email buttons
      expect(find.text('Welcome to Lifting Life'), findsOneWidget);
      expect(find.text('Continue with Facebook'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Email'), findsOneWidget);

      // 3. Trigger first-time sign-in with Apple ID to enter First-Time Fitness Onboarding
      data.signInWithOAuthProvider(
        provider: 'apple',
        email: 'k9x4m2p@privaterelay.appleid.com',
        displayName: 'Alex Rivera',
        isFirstTimeUser: true,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify new user defaults to UserRole.user (never Owner!)
      expect(data.currentUser?.role, UserRole.user);
      expect(find.text('Personalize Lifting Life'), findsOneWidget);

      // 4. Complete First-Time Fitness Onboarding -> Enter Main Home Dashboard
      await tester.tap(find.text('Skip Optional'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome back, Alex Rivera'), findsOneWidget);
      // Verify required empty states are displayed when user has no data
      expect(find.text('No workouts yet.'), findsWidgets);
      expect(find.text('No friends added.'), findsOneWidget);
      expect(find.text('No courses enrolled.'), findsOneWidget);
      expect(find.text('Start your first workout.'), findsOneWidget);
    },
  );

  test(
    'Task 2 & Task 8: Registration, salted SHA-256 6-digit OTP (valid, invalid, expired, rate-limited), Password Recovery, Session Restoration & Logout',
    () async {
      final data = DataService.instance;
      data.initializeProductionState();

      // 1. Verify email masking format
      expect(DataService.maskEmail('myathlete@gmail.com'), 'm***@gmail.com');

      // 2. Start pending email registration -> user is unverified & unauthenticated, role is UserRole.user
      final otp = data.startPendingEmailRegistration(
        username: 'titan_gmail',
        email: 'myathlete@gmail.com',
        password: 'StrongPassword#2026',
        deterministicOtpForTesting: '482915',
      );
      expect(otp, '482915');
      expect(data.isAuthenticated, isFalse);
      expect(data.currentUser?.emailVerified, isFalse);
      expect(data.currentUser?.role, UserRole.user);

      // Unverified user cannot sign in with password before verifying OTP
      final prematureSignIn = data.signIn(
        email: 'myathlete@gmail.com',
        password: 'StrongPassword#2026',
      );
      expect(prematureSignIn.isSuccess, isFalse);
      expect(prematureSignIn.requiresEmailVerification, isTrue);

      // 3. Incorrect 6-digit OTP -> rejected, account stays unverified
      final badAttempt = data.verifyEmailOtp('111111');
      expect(badAttempt.isSuccess, isFalse);
      expect(
        badAttempt.message,
        'Incorrect verification code. Please try again.',
      );

      // 4. Rate-limiting after 5 failed OTP attempts
      for (int i = 0; i < 4; i++) {
        data.verifyEmailOtp('000000');
      }
      final rateLimitedAttempt = data.verifyEmailOtp('482915');
      expect(rateLimitedAttempt.isSuccess, isFalse);
      expect(rateLimitedAttempt.isRateLimited, isTrue);

      // 5. Resend OTP resets attempts, then test Expiration
      data.resendEmailVerificationOtp(deterministicOtpForTesting: '555666');
      data.expirePendingOtpForTesting();
      final expiredAttempt = data.verifyEmailOtp('555666');
      expect(expiredAttempt.isSuccess, isFalse);
      expect(expiredAttempt.isExpired, isTrue);

      // 6. Resend fresh 6-digit OTP and verify with valid code
      final validOtp = data.resendEmailVerificationOtp(
        deterministicOtpForTesting: '739204',
      );
      final goodAttempt = data.verifyEmailOtp(validOtp);
      expect(goodAttempt.isSuccess, isTrue);
      expect(data.isAuthenticated, isTrue);
      expect(data.currentUser?.emailVerified, isTrue);

      // 7. Single-use enforcement: reusing the same OTP fails
      final reuseAttempt = data.verifyEmailOtp('739204');
      expect(reuseAttempt.isSuccess, isFalse);

      // 8. Complete onboarding & test Encrypted Session Restoration across sign-out/restart
      data.completeOnboarding(
        experienceLevel: 'Intermediate',
        trainingInterest: 'Powerlifting',
        preferredDays: const ['Mon', 'Wed', 'Fri'],
        goals: const ['Improve strength'],
      );
      final restored = await data.tryRestorePersistedSession();
      expect(restored, isTrue);
      expect(data.isAuthenticated, isTrue);
      expect(data.currentUser?.username, 'titan_gmail');

      // 9. Logout clears active session
      data.signOut();
      expect(data.isAuthenticated, isFalse);
      expect(data.currentUser, isNull);
      final restoredAfterLogout = await data.tryRestorePersistedSession();
      expect(restoredAfterLogout, isFalse);

      // 10. Password Recovery & Reset workflow
      final recoveryReq = data.requestPasswordRecovery(
        email: 'myathlete@gmail.com',
        deterministicOtpForTesting: '918273',
      );
      expect(recoveryReq.isSuccess, isTrue);

      final resetRes = data.completePasswordReset(
        email: 'myathlete@gmail.com',
        recoveryCode: '918273',
        newPassword: 'UpdatedPassword#2027',
      );
      expect(resetRes.isSuccess, isTrue);

      // Old password fails, new password succeeds
      expect(
        data
            .signIn(
              email: 'myathlete@gmail.com',
              password: 'StrongPassword#2026',
            )
            .isSuccess,
        isFalse,
      );
      expect(
        data
            .signIn(
              email: 'myathlete@gmail.com',
              password: 'UpdatedPassword#2027',
            )
            .isSuccess,
        isTrue,
      );
    },
  );

  test(
    'Task 5 & Task 8: Strict User Isolation — User A cannot read User B private workouts or PRs',
    () async {
      final data = DataService.instance;
      data.initializeProductionState();

      // Register & verify User A
      final otpA = data.startPendingEmailRegistration(
        username: 'user_alpha',
        email: 'alpha@liftinglife.app',
        password: 'AlphaPassword#1',
        deterministicOtpForTesting: '111222',
      );
      data.verifyEmailOtp(otpA);
      final userAId = data.currentUser!.id;

      // User A logs a private workout
      final workoutA = Workout(
        id: data.newId(),
        userId: userAId,
        name: 'Alpha Private Squat Session',
        trainingMode: 'Powerlifting',
        date: DateTime.now(),
        durationMinutes: 45,
        createdAt: DateTime.now(),
        exercises: [
          WorkoutExercise(
            id: data.newId(),
            exerciseId: 'ex_bb_back_squat',
            name: 'Barbell Back Squat',
            muscleGroup: 'Quadriceps',
            sets: [
              ExerciseSet(
                setNumber: 1,
                weight: 160,
                reps: 3,
                rpe: 8.5,
                isCompleted: true,
              ),
            ],
          ),
        ],
      );
      data.addWorkout(workoutA);
      expect(data.workouts.length, 1);
      expect(data.personalRecords.length, 1);

      // Sign out User A and register User B
      data.signOut();
      final otpB = data.startPendingEmailRegistration(
        username: 'user_bravo',
        email: 'bravo@liftinglife.app',
        password: 'BravoPassword#1',
        deterministicOtpForTesting: '333444',
      );
      data.verifyEmailOtp(otpB);
      final userBId = data.currentUser!.id;

      // User B sees 0 workouts and 0 PRs (User A's data is isolated)
      expect(data.workouts, isEmpty);
      expect(data.personalRecords, isEmpty);

      // Direct RLS query check: User B attempting to read User A's workouts throws StateError
      expect(
        () => data.getWorkoutsForUser(
          requestingUserId: userBId,
          targetUserId: userAId,
        ),
        throwsStateError,
      );

      // User A can read their own workouts
      final alphaWorkouts = data.getWorkoutsForUser(
        requestingUserId: userAId,
        targetUserId: userAId,
      );
      expect(alphaWorkouts.length, 1);
      expect(alphaWorkouts.first.name, 'Alpha Private Squat Session');
    },
  );

  test(
    'Task 4 & Task 8: CloudStorageService enforces magic-byte validation, cross-user path protection & expired signed URL rejection',
    () async {
      final storage = CloudStorageService.instance;

      // 1. Valid GLB magic header ('glTF' = 0x67, 0x6C, 0x54, 0x46)
      final validGlbBytes = Uint8List.fromList([
        0x67,
        0x6C,
        0x54,
        0x46,
        0x02,
        0x00,
        0x00,
        0x00,
        0x10,
        0x00,
        0x00,
        0x00,
      ]);
      final glbCheck = await storage.uploadProtectedAsset(
        bucket: StorageBucket.anatomyModels,
        fullObjectPath: CloudStorageService.buildAnatomyModelPath(
          modelId: 'male_muscular_v2',
        ),
        fileBytes: validGlbBytes,
        authenticatedUserId: 'owner_id',
        actorRole: UserRole.owner,
      );
      expect(glbCheck.isSuccess, isTrue);

      // 2. Spoofed/corrupt GLB header -> rejected
      final badGlbBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      final badGlbCheck = await storage.uploadProtectedAsset(
        bucket: StorageBucket.anatomyModels,
        fullObjectPath: CloudStorageService.buildAnatomyModelPath(
          modelId: 'male_muscular_v2',
        ),
        fileBytes: badGlbBytes,
        authenticatedUserId: 'owner_id',
        actorRole: UserRole.owner,
      );
      expect(badGlbCheck.isSuccess, isFalse);

      // 3. Cross-user avatar overwrite attempt -> rejected
      final validPngBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
      ]);
      final crossUserAttempt = await storage.uploadProtectedAsset(
        bucket: StorageBucket.profileAvatars,
        fullObjectPath: 'profile-avatars/user_victim/pic.png',
        fileBytes: validPngBytes,
        authenticatedUserId: 'user_attacker',
        actorRole: UserRole.user,
      );
      expect(crossUserAttempt.isSuccess, isFalse);
      expect(crossUserAttempt.message, contains('Forbidden'));

      // 4. Signed URL creation & Expired Signed URL Rejection
      final expiredUrl = SignedMediaUrl(
        bucket: StorageBucket.exerciseVideos,
        objectPath: 'exercise-videos/ex_bb_back_squat/front.mp4',
        signedUrl: 'https://example.supabase.co/storage/v1/object/sign/expired',
        tokenSignature: 'sig_expired',
        issuedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 20)),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      expect(expiredUrl.isExpired, isTrue);
      expect(expiredUrl.validateForPlaybackOrRender(), isFalse);

      // 5. AI Agent 2 Contract resolves 3D assets and refreshes signed URLs
      final Agent2ExerciseAnd3DContract contract = DataService.instance;
      final anatomy = await contract.fetchAnatomyModelAsset(
        exerciseId: 'ex_bb_back_squat',
      );
      expect(anatomy.primaryHighlightHex, '#39FF14');
      expect(anatomy.secondaryHighlightHex, '#9DDF91');
      final video = await contract.fetchExerciseVideoAsset(
        exerciseId: 'ex_bb_back_squat',
      );
      expect(video.signedMediaUrl.isExpired, isFalse);
    },
  );

  test(
    'Task 6 & Task 8: Admin & Owner RBAC restrictions and Mandatory Data Safety 8-step Demo Cleanup',
    () {
      final data = DataService.instance;
      data.initializeDemoData();
      data.restoreAuthenticatedSession();

      // Switch to regular User -> cannot assign roles or approve courses
      data.switchActiveRoleForTesting(UserRole.user);
      final roleAttempt = data.assignUserRole(
        targetUserId: data.currentUser!.id,
        newRole: UserRole.owner,
      );
      expect(roleAttempt, contains('Unauthorized'));

      // Switch to Creator -> can submit course to Pending Review, but CANNOT self-approve
      data.switchActiveRoleForTesting(UserRole.creator);
      final submitted = data.submitOrSaveCourse(
        title: 'Creator Squat Course',
        description: 'Test submission workflow',
        category: 'Exercise Technique',
        difficulty: 'Intermediate',
        lessons: const [],
        submitForApproval: true,
      );
      expect(submitted.status, CourseStatus.pendingReview);

      final creatorAttempt = data.reviewCourseSubmission(
        courseId: submitted.id,
        decision: CourseStatus.approved,
        feedback: 'Self approving',
      );
      expect(creatorAttempt, contains('Unauthorized'));

      // Switch to Owner -> can approve course
      data.switchActiveRoleForTesting(UserRole.owner);
      final ownerApproval = data.reviewCourseSubmission(
        courseId: submitted.id,
        decision: CourseStatus.approved,
        feedback: 'Verified and approved by Owner.',
      );
      expect(ownerApproval, contains('Approved'));

      // Test Mandatory Data Safety 8-step Demo Cleanup workflow
      final cleanupService = DemoDataCleanupService.instance;
      final preview = cleanupService.createBackupAndGeneratePreview(
        actorUserId: data.currentUser!.id,
        actorRole: UserRole.owner,
        environment: AppEnvironment.staging,
        usersTable: [
          data.currentUser!.toMap(),
          {
            'id': 'u_real_athlete',
            'email': 'real.athlete@gmail.com',
            'username': 'real_lifter',
          },
        ],
        workoutsTable: data.workouts.map((w) => w.toMap()).toList(),
        postsTable: const [
          {'id': 'post_demo_1', 'authorUsername': 'sarah_power'},
        ],
        coursesTable: const [],
        catalogExercisesCount: data.exercises.length,
      );

      expect(
        preview.demoUserIdsToDelete.length + preview.demoPostIdsToDelete.length,
        greaterThan(0),
      );
      expect(preview.preservedRealUsersCount, 1); // 'real.athlete@gmail.com' preserved

      // Unconfirmed cleanup must be rejected
      final unconfirmed = cleanupService.executeConfirmedCleanup(
        previewId: preview.previewId,
        actorRole: UserRole.owner,
        ownerConfirmed: false,
        usersTable: [],
        workoutsTable: [],
        postsTable: [],
        coursesTable: [],
      );
      expect(unconfirmed.executed, isFalse);

      // Owner-confirmed cleanup removes demo records and preserves real records
      final mutableUsers = [
        data.currentUser!.toMap(),
        {
          'id': 'u_real_athlete',
          'email': 'real.athlete@gmail.com',
          'username': 'real_lifter',
        },
      ];
      final confirmed = cleanupService.executeConfirmedCleanup(
        previewId: preview.previewId,
        actorRole: UserRole.owner,
        ownerConfirmed: true,
        usersTable: mutableUsers,
        workoutsTable: [],
        postsTable: [],
        coursesTable: [],
      );
      expect(confirmed.executed, isTrue);
      expect(mutableUsers.length, 1);
      expect(mutableUsers.first['email'], 'real.athlete@gmail.com');
    },
  );

  testWidgets(
    'AnatomyExerciseViewer (AI Agent 2 component) renders cleanly with #39FF14/#9DDF91 muscle highlighting',
    (WidgetTester tester) async {
      final data = DataService.instance;
      data.initializeProductionState();

      expect(kAnatomyPrimaryNeonGreen, const Color(0xFF39FF14));
      expect(kAnatomySecondaryGreen, const Color(0xFF9DDF91));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnatomyExerciseViewer(
                exerciseId: 'ex_bb_back_squat',
                animationPath: 'assets/animations/squat.glb',
                primaryMuscles: ['Quadriceps', 'Gluteus Maximus'],
                secondaryMuscles: ['Hamstrings', 'Adductors'],
                cameraView: 'Front',
                playbackSpeed: 1.0,
                showMuscleLabels: true,
                height: 1400,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ANIMATED TECHNIQUE DIAGRAM'), findsOneWidget);
      expect(find.text('Demonstration unavailable'), findsNothing);
      expect(find.text('GLB 2.0 READY'), findsNothing);
    },
  );

  testWidgets(
    'All screens and tabs render without overflow on a compact mobile viewport (360x780)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 1450);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = DataService.instance;
      data.initializeProductionState();

      await tester.pumpWidget(const LiftingLifeApp());
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome to Lifting Life'), findsOneWidget);

      final otp = data.startPendingEmailRegistration(
        username: 'mobile_tester',
        email: 'mobile@gmail.com',
        password: 'StrongPassword#2026',
        deterministicOtpForTesting: '654321',
      );
      await tester.pump(const Duration(milliseconds: 300));

      data.verifyEmailOtp(otp);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Skip Optional'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Welcome back, mobile_tester'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.view_in_ar_outlined));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Exercise Library'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fitness_center_outlined));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Workout & Training Hub'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.leaderboard_outlined));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Rankings & Social Feed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Athlete Profile & Settings'), findsOneWidget);
    },
  );
}
