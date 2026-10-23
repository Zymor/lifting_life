import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/core/security/secure_session_storage.dart';
import 'package:tp1/models/workout.dart';
import 'package:tp1/screens/workouts_screen.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  final data = DataService.instance;
  const email = 'demo.lifter.4821@example.com';
  const password = 'V9!qR7#zL2@mK8';
  Future<void> login() async {
    data.initializeProductionState();
    data.registerTestAthleteAccount(
      email: email,
      password: password,
      username: 'reliability_lifter',
    );
    expect(data.signIn(email: email, password: password).isSuccess, isTrue);
    await Future<void>.delayed(Duration.zero);
  }
  Workout workout({String id = 'test_session', bool complete = true, String? owner}) => Workout(
    id: id, userId: owner ?? data.currentUser!.id, name: 'Test workout',
    date: DateTime.now(), createdAt: DateTime.now(), exercises: [
      WorkoutExercise(id: 'exercise', name: 'Bench Press', muscleGroup: 'Chest',
        sets: [ExerciseSet(weight: 50, reps: 8, isCompleted: complete)]),
    ],
  );

  test('completed workout persists across immediate logout without data loss', () async {
    await login();
    final uid = data.currentUser!.id;
    final draft = workout();
    await data.saveActiveWorkoutDraft(draft);
    data.addWorkout(draft);
    data.signOut();
    await Future<void>.delayed(Duration.zero);
    final saved = await SecureSessionStorage.instance.readUserScopedJson(userId: uid, collection: 'workouts') as Map;
    expect((saved['items'] as List).length, 1);
    expect(data.isAuthenticated, isFalse);
    expect(data.workouts, isEmpty);
    data.signIn(email: email, password: password);
    await Future<void>.delayed(Duration.zero);
    expect(data.workouts.single.id, draft.id);
  });

  test('draft edits preserve latest value and recover after logout', () async {
    await login();
    final first = workout(complete: false);
    await Future.wait([
      data.saveActiveWorkoutDraft(first),
      data.saveActiveWorkoutDraft(first.copyWith(name: 'Latest draft')),
    ]);
    data.signOut();
    await Future<void>.delayed(Duration.zero);
    data.signIn(email: email, password: password);
    await Future<void>.delayed(Duration.zero);
    expect(data.activeWorkoutDraft?.name, 'Latest draft');
    expect(data.activeWorkoutDraft?.completedSets, 0);
  });

  test('incomplete, foreign, and duplicate workouts cannot award progress', () async {
    await login();
    data.addWorkout(workout(complete: false));
    data.addWorkout(workout(owner: 'another-user'));
    expect(data.workouts, isEmpty);
    await expectLater(data.saveActiveWorkoutDraft(workout(owner: 'another-user')), throwsStateError);
    final completed = workout();
    data.addWorkout(completed);
    final xp = data.currentUser!.xpPoints;
    data.addWorkout(completed);
    expect(data.workouts.length, 1);
    expect(data.currentUser!.xpPoints, xp);
  });

  testWidgets('opening logger creates no fabricated session; start is empty at large text', (tester) async {
    await tester.runAsync(login);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
      child: child!), home: const WorkoutsScreen()));
    await tester.pump();
    expect(data.activeWorkoutDraft, isNull);
    await tester.tap(find.text('START NEW WORKOUT SESSION'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(data.activeWorkoutDraft?.exercises, isEmpty);
    expect(data.activeWorkoutDraft?.completedSets, 0);
    expect(find.text('27:00'), findsNothing);
    expect(tester.takeException(), isNull);
    await data.saveActiveWorkoutDraft(null);
    data.signOut();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
