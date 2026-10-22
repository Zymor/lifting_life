import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/data/opengym_catalogue.dart';
import 'package:tp1/data/exercise_seed_data.dart';
import 'package:tp1/core/security/secure_session_storage.dart';
import 'package:tp1/models/workout.dart';
import 'package:tp1/services/data_service.dart';
import 'package:tp1/services/training_plan_store.dart';
import 'package:tp1/screens/planner_screen.dart';
import 'package:tp1/services/progression.dart';
import 'package:tp1/models/nutrition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = DataService.instance;
  Workout routine() => Workout(
    id: 'template',
    userId: 'system_catalog',
    name: 'Routine',
    date: DateTime(2020),
    createdAt: DateTime(2020),
    isTemplate: true,
    exercises: [
      WorkoutExercise(
        id: 'e',
        name: 'Squat',
        muscleGroup: 'Quadriceps',
        sets: [ExerciseSet(reps: 5, weight: 60)],
      ),
    ],
  );
  const testEmail = 'athlete.test@liftinglife.app';
  const testPassword = 'StrongPassword123!';
  Future<void> login() async {
    data.initializeProductionState();
    data.registerTestAthleteAccount(
      email: testEmail,
      password: testPassword,
      username: 'test_athlete',
    );
    expect(
      data
          .signIn(
            email: testEmail,
            password: testPassword,
          )
          .isSuccess,
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('bundled catalogue is complete, uniquely identified and excludes media paths', () async {
    final catalogue = await OpenGymCatalogue.load();
    expect(catalogue.length, 6554);
    expect(catalogue.map((e) => e.id).toSet().length, catalogue.length);
    expect(
      catalogue.every((e) => e.glbAssetPath == null && !e.has3dAnimation),
      isTrue,
    );
    final original = ExerciseSeedData.build200PlusExercises();
    final merged = OpenGymCatalogue.merge(original, catalogue);
    expect(merged.take(original.length), orderedEquals(original));
    expect(OpenGymCatalogue.merge(merged, catalogue).length, merged.length);
    expect(merged.length, greaterThan(3000));
  });
  test('weekly plan, rest overrides, rotations and measurements survive reload and isolate users', () async {
    SecureSessionStorage.instance.clearMemoryVaultForTesting();
    final store = TrainingPlanStore('a');
    final date = DateTime(2026, 10, 26);
    store.weekly[1] = routine();
    store.overrides[TrainingPlanStore.dayKey(date)] = null;
    store.rotation.add(routine());
    store.recordWeight(date, 75.5);
    await store.save();
    final restored = TrainingPlanStore('a');
    await restored.load();
    expect(restored.forDate(date), isNull);
    expect(
      restored.forDate(date.add(const Duration(days: 7)))?.name,
      'Routine',
    );
    restored.useRotation = true;
    expect(
      restored.forDate(date.add(const Duration(days: 1)))?.name,
      'Routine',
    );
    expect(restored.weighIns.values.single, 75.5);
    final other = TrainingPlanStore('b');
    await other.load();
    expect(other.weekly, isEmpty);
    expect(other.weighIns, isEmpty);
    expect(() => restored.recordWeight(date, double.nan), throwsArgumentError);
  });
  test('starting a routine resets ownership, completion, dates and prevents draft overwrite', () async {
    await login();
    await data.startRoutine(routine());
    final draft = data.activeWorkoutDraft!;
    expect(draft.userId, data.currentUser!.id);
    expect(draft.createdAt.year, DateTime.now().year);
    expect(draft.isTemplate, isFalse);
    expect(draft.completedSets, 0);
    expect(draft.exercises.single.sets.single.weight, 60);
    await expectLater(data.startRoutine(routine()), throwsStateError);
  });
  test('favorites and templates restore after logout', () async {
    await login();
    data.toggleFavoriteExercise('ex_bb_bench_press');
    data.saveWorkoutTemplate(routine());
    final uid = data.currentUser!.id;
    data.signOut();
    await SecureSessionStorage.instance.readUserScopedJson(
      userId: uid,
      collection: 'templates',
    );
    data.signIn(
      email: testEmail,
      password: testPassword,
    );
    await Future<void>.delayed(Duration.zero);
    expect(data.favoriteExerciseIds, contains('ex_bb_bench_press'));
    expect(data.workoutTemplates.where((w) => w.name == 'Routine').length, 1);
  });
  test(
    'progression never increases load for missed or incomplete working sets',
    () {
      WorkoutExercise exercise(List<ExerciseSet> sets) => WorkoutExercise(
        id: 'e',
        name: 'Press',
        muscleGroup: 'Chest',
        sets: sets,
      );
      expect(
        ProgressionTarget.next(exercise([ExerciseSet(weight: 50, reps: 12)]))!
            .weight,
        52.5,
      );
      expect(
        ProgressionTarget.next(exercise([ExerciseSet(weight: 50, reps: 6)]))!
            .weight,
        50,
      );
      expect(
        ProgressionTarget.next(
          exercise([
            ExerciseSet(weight: 50, reps: 12),
            ExerciseSet(weight: 50, reps: 12, isCompleted: false),
          ]),
        )!.weight,
        50,
      );
      expect(
        ProgressionTarget.next(exercise([ExerciseSet(weight: 0, reps: 12)]))!
            .weight,
        0,
      );
    },
  );
  test(
    'history correction recomputes records without awarding XP again',
    () async {
      await login();
      await data.startRoutine(routine());
      final draft = data.activeWorkoutDraft!;
      final completed = draft.copyWith(
        exercises: draft.exercises
            .map(
              (e) => e.copyWith(
                sets: e.sets.map((s) => s.copyWith(isCompleted: true)).toList(),
              ),
            )
            .toList(),
      );
      data.addWorkout(completed);
      final xp = data.currentUser!.xpPoints;
      final exercise = completed.exercises.single;
      await data.correctWorkout(
        completed.copyWith(
          exercises: [
            exercise.copyWith(
              sets: [exercise.sets.single.copyWith(weight: 30)],
            ),
          ],
        ),
      );
      expect(data.personalRecords.single.weightKg, 30);
      expect(data.currentUser!.xpPoints, xp);
      expect(data.workouts.length, 1);
    },
  );
  test('nutrition is persisted and included in complete exports', () async {
    await login();
    final uid = data.currentUser!.id;
    final now = DateTime.now();
    data.addMeal(
      MealEntry(
        id: 'meal',
        userId: uid,
        mealType: 'breakfast',
        foodId: 'oats',
        foodName: 'Oats',
        quantity: 100,
        calories: 379,
        protein: 13,
        carbs: 67,
        fat: 6,
        date: now,
        createdAt: now,
      ),
    );
    data.signOut();
    final stored = await SecureSessionStorage.instance.readUserScopedJson(
      userId: uid,
      collection: 'nutrition_journal_v1',
    ) as Map;
    expect((stored['meals'] as List).length, 1);
    expect(data.meals, isEmpty);
    data.signIn(
      email: testEmail,
      password: testPassword,
    );
    await Future<void>.delayed(Duration.zero);
    expect(data.meals.single.id, 'meal');
    expect(await data.exportCompleteUserDataJson(), contains('trainingPlan'));
  });
  testWidgets(
    'planner renders on a narrow display and assigns a weekly routine',
    (tester) async {
      await tester.runAsync(login);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: PlannerScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Build your training week'), findsOneWidget);
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(data.workoutTemplates.first.name).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final store = TrainingPlanStore(data.currentUser!.id);
      await store.load();
      expect(store.weekly[1]?.name, data.workoutTemplates.first.name);
    },
  );
}
