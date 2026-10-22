import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/app_theme.dart';
import 'package:tp1/models/exercise.dart';
import 'package:tp1/screens/exercises_screen.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal Exercise Detail & OpenGym Library Tests', () {
    late DataService data;

    setUp(() {
      data = DataService.instance;
      data.initializeProductionState();
    });

    final testBenchPress = Exercise(
      id: 'opengym_0025',
      name: 'Barbell Bench Press',
      category: 'Chest',
      primaryMuscles: const ['Pectorals'],
      secondaryMuscles: const ['Triceps', 'Shoulders'],
      equipment: 'Barbell',
      difficulty: 'Intermediate',
      instructions: const [
        'Lie flat on a bench with your feet flat on the ground.',
        'Grasp the barbell with an overhand grip slightly wider than shoulder-width.',
        'Lower the bar slowly to mid-chest with elbows at ~45-75 degrees.',
        'Press upward forcefully back to the starting locked-out position.',
      ],
      techniqueTips: const [
        'Maintain a stable arch and retract shoulder blades against the bench.',
      ],
      commonMistakes: const [
        'Bouncing the barbell off the sternum.',
        'Flaring elbows out at 90 degrees.',
      ],
      alternativeNames: const ['Flat Bench', 'Chest Press'],
      movementPattern: 'bench',
      startPositionDesc: 'Eyes directly beneath racked bar, feet planted.',
      endPositionDesc: 'Arms extended with bar directly over shoulder joints.',
      movementPathDesc: 'Slight J-curve from lower sternum to over shoulders.',
      description: 'The classic compound barbell lift for chest, anterior delts, and triceps.',
      mediaUrl: 'exercise-media/clip/0025.mp4',
      thumbnailUrl: 'exercise-media/still/0025.webp',
      resistanceType: 'per_side',
      source: 'opengym',
    );

    final testDumbbellCurl = Exercise(
      id: 'opengym_0312',
      name: 'Dumbbell Bicep Curl',
      category: 'Biceps',
      primaryMuscles: const ['Biceps'],
      secondaryMuscles: const ['Brachialis', 'Forearms'],
      equipment: 'Dumbbell',
      difficulty: 'Beginner',
      instructions: const [
        'Stand tall with dumbbells at your sides, palms facing inward.',
        'Curl weights upward while supinating wrists until palms face your shoulders.',
        'Squeeze biceps at the peak, then lower under control.',
      ],
      techniqueTips: const ['Keep elbows pinned at your sides.'],
      commonMistakes: const ['Swinging hips to cheat weights upward.'],
      alternativeNames: const ['Biceps Curl'],
      movementPattern: 'curl',
      startPositionDesc: 'Arms fully extended, dumbbells at thighs.',
      endPositionDesc: 'Peak bicep contraction.',
      movementPathDesc: 'Curvilinear arc.',
      description: 'Isolation exercise targeting both heads of the biceps brachii.',
      resistanceType: 'dumbbell',
      source: 'opengym',
    );

    final testPushup = Exercise(
      id: 'opengym_0662',
      name: 'Standard Push-Up',
      category: 'Chest',
      primaryMuscles: const ['Pectorals'],
      secondaryMuscles: const ['Triceps', 'Delts', 'Core'],
      equipment: 'Bodyweight',
      difficulty: 'Beginner',
      instructions: const [
        'Assume high plank position with hands slightly wider than shoulder width.',
        'Lower your chest toward the floor until elbows reach 90 degrees.',
        'Push the floor away to return to top plank position.',
      ],
      techniqueTips: const ['Engage glutes and abs to avoid sagging hips.'],
      commonMistakes: const ['Flaring elbows wide', 'Sagging hips'],
      alternativeNames: const ['Press Up'],
      movementPattern: 'bench',
      startPositionDesc: 'High plank.',
      endPositionDesc: 'Chest 1 inch off floor.',
      movementPathDesc: 'Linear descent and press.',
      description: 'Fundamental horizontal push calisthenic movement.',
      resistanceType: 'bodyweight',
      source: 'opengym',
    );

    final testJumpRope = Exercise(
      id: 'opengym_1200',
      name: 'Jump Rope Conditioning',
      category: 'Full-Body',
      primaryMuscles: const ['Cardiovascular System'],
      secondaryMuscles: const ['Calves', 'Shoulders'],
      equipment: 'Rope',
      difficulty: 'Beginner',
      instructions: const [
        'Hold jump rope handles with elbows close to your torso.',
        'Rotate wrists to swing rope overhead while hopping lightly on balls of feet.',
      ],
      techniqueTips: const ['Stay light on your feet.'],
      commonMistakes: const ['Jumping too high.'],
      alternativeNames: const ['Skipping'],
      movementPattern: 'cardio',
      startPositionDesc: 'Rope behind heels.',
      endPositionDesc: 'Continuous hopping cadence.',
      movementPathDesc: 'Rotational arc.',
      description: 'High-intensity cardiovascular agility conditioning.',
      resistanceType: 'cardio',
      source: 'opengym',
    );

    testWidgets('Header displays exercise name and toggles favorite star', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header Exercise Name in AppBar
      expect(find.widgetWithText(AppBar, 'Barbell Bench Press'), findsOneWidget);

      // Check Favorite Star button
      final favButton = find.byTooltip('Add to Favorites');
      expect(favButton, findsOneWidget);

      // Tap favorite star
      await tester.tap(favButton);
      await tester.pumpAndSettle();

      expect(data.favoriteExerciseIds.contains(testBenchPress.id), isTrue);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('Dynamic tags show relevant muscles and equipment accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      // Category chip
      expect(find.text('Chest'), findsWidgets);
      // Primary muscle chip
      expect(find.text('Pectorals'), findsOneWidget);
      // Equipment chip
      expect(find.text('Barbell'), findsWidgets);
      // Secondary muscles
      expect(find.text('Triceps'), findsOneWidget);
      expect(find.text('Shoulders'), findsOneWidget);
      // Difficulty
      expect(find.text('Intermediate'), findsOneWidget);
    });

    testWidgets('Exercise description and instructions render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      // Overview description text
      expect(find.text('The classic compound barbell lift for chest, anterior delts, and triceps.'), findsOneWidget);

      // Step-by-step instructions section
      expect(find.text('Step-by-Step Instructions'), findsOneWidget);
      expect(find.text('Lie flat on a bench with your feet flat on the ground.'), findsOneWidget);
    });

    testWidgets('+ Add to My Plan button opens plan modal and saves to routine', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      // Check "+ Add to My Plan" button
      final addToPlanBtn = find.text('+ Add to My Plan');
      expect(addToPlanBtn, findsOneWidget);

      // Tap button to open modal
      await tester.tap(addToPlanBtn);
      await tester.pumpAndSettle();

      // Modal content should be visible
      expect(find.text('Add to Workout Plan'), findsOneWidget);
      expect(find.text('Select Existing Routine'), findsOneWidget);

      // Should show standard templates (e.g. Push Day, Pull Day, Leg Day)
      final pushDayItem = find.text('PPL — Push Hypertrophy A');
      expect(pushDayItem, findsOneWidget);

      // Tap to add to Push Day
      await tester.tap(pushDayItem);
      await tester.pumpAndSettle();

      // Verification: Push template now contains testBenchPress
      final pushTemplate = data.workoutTemplates.firstWhere(
        (t) => t.name.contains('Push'),
      );
      expect(
        pushTemplate.exercises.any((e) => e.exerciseId == testBenchPress.id || e.name == testBenchPress.name),
        isTrue,
      );
    });

    testWidgets('Create New Routine in Add to Plan modal works and persists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      // Open Add to Plan
      await tester.tap(find.text('+ Add to My Plan'));
      await tester.pumpAndSettle();

      // Switch to New Plan
      await tester.tap(find.text('New Plan'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Workout Routine'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField), 'My Champion Chest Split');
      await tester.pumpAndSettle();

      // Tap Create & Add
      await tester.tap(find.text('Create & Add'));
      await tester.pumpAndSettle();

      // Check that new plan exists in DataService templates
      final createdPlan = data.workoutTemplates.firstWhere(
        (t) => t.name == 'My Champion Chest Split',
      );
      expect(createdPlan, isNotNull);
      expect(createdPlan.exercises.any((e) => e.name == testBenchPress.name), isTrue);
    });

    testWidgets('Plate loading appears for barbell and is hidden for bodyweight and cardio', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Barbell: Plate loading section is visible
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plate Loading & Resistance'), findsOneWidget);
      expect(find.text('Per side'), findsOneWidget);
      expect(find.text('Plate Calculator'), findsOneWidget);

      // 2. Dumbbell: shows dumbbell load options
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testDumbbellCurl),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dumbbell Load Configuration'), findsOneWidget);
      expect(find.text('Each dumbbell'), findsOneWidget);

      // 3. Bodyweight: plate loading is hidden
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testPushup),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resistance: Bodyweight'), findsOneWidget);
      expect(find.text('Per side'), findsNothing);

      // 4. Cardio: plate loading is hidden
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testJumpRope),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cardiovascular Tracking'), findsOneWidget);
      expect(find.text('Plate Loading & Resistance'), findsNothing);
    });

    testWidgets('Estimated 1RM calculator live updates on stepper adjustments', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(exercise: testBenchPress),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estimated One-Rep Max (1RM)'), findsOneWidget);
      // Default: 60 kg x 8 reps = 60 * (1 + 8/30) = 76.0 kg
      expect(find.text('76.0 kg'), findsOneWidget);

      // Tap plus on weight (+2.5 kg -> 62.5 kg)
      final plusWeight = find.byIcon(Icons.add).first;
      await tester.tap(plusWeight);
      await tester.pumpAndSettle();

      // 62.5 * (1 + 8/30) = 79.16 -> 79.2 kg
      expect(find.text('79.2 kg'), findsOneWidget);
    });

    testWidgets('Library screen search and category filtering work properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ExercisesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Exercise library header
      expect(find.text('Exercise Library'), findsOneWidget);

      // Search field
      await tester.enterText(find.byType(TextField), 'Bench');
      await tester.pumpAndSettle();

      // Category chip tap
      await tester.tap(find.text('Chest').first);
      await tester.pumpAndSettle();

      // Exercises should be filtered
      expect(find.byType(Card), findsWidgets);
    });
  });
}
