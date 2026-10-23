// Local synthetic performance scenario. Never used by lib/main.dart.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tp1/app_theme.dart';
import 'package:tp1/screens/workouts_screen.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final data = DataService.instance;
  data.registerAccount(email: 'benchmark@example.com', username: 'benchmark',
    name: 'Local benchmark', startOnboarding: false);
  final frames = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback(frames.addAll);
  runApp(MaterialApp(theme: AppTheme.darkTheme, home: const WorkoutsScreen()));
  Timer(const Duration(seconds: 12), () {
    final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()..sort();
    final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()..sort();
    int p95(List<int> values) => values.isEmpty ? 0 : values[((values.length - 1) * .95).round()];
    stdout.writeln('WORKOUT_PROFILE frames=${frames.length} build_p95_us=${p95(build)} raster_p95_us=${p95(raster)} rss_bytes=${ProcessInfo.currentRss}');
    exit(0);
  });
}
