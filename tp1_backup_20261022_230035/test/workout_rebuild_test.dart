import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/screens/workouts_screen.dart';
import 'package:tp1/services/data_service.dart';
import 'package:tp1/models/workout.dart';

void main() {
  testWidgets('measure idle workout logger rebuilds over five timer ticks', (tester) async {
    final data = DataService.instance;
    data.initializeProductionState();
    data.signIn(email: 'demo.lifter.4821@example.com', password: 'V9!qR7#zL2@mK8');
    await tester.pump();
    await data.saveActiveWorkoutDraft(Workout(id: 'perf_draft', userId: data.currentUser!.id,
      name: 'Performance draft', date: DateTime.now(), createdAt: DateTime.now(), exercises: []));
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: WorkoutsScreen()));
    await tester.pump();
    var loggerBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is WorkoutsScreen) loggerBuilds++;
    };
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    debugOnRebuildDirtyWidget = null;
    expect(loggerBuilds, 0, reason: 'Timer ticks should only rebuild the clock.');
    // ignore: avoid_print
    print('LOGGER_REBUILDS_OVER_5_SECONDS=$loggerBuilds');
    await tester.pumpWidget(const SizedBox());
    data.signOut();
    await tester.pump();
  });
}
