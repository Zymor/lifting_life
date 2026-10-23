import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/widgets/back_extension_diagram.dart';
import 'package:tp1/widgets/exercise_3d_viewer.dart';
import 'package:tp1/data/exercise_seed_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final file = File('C:/Windows/Fonts/segoeui.ttf');
    if (file.existsSync()) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Widget host(Widget child, {bool reduced = false, bool enabled = true}) =>
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Preview'),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 1200),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: TickerMode(
              enabled: enabled,
              child: SingleChildScrollView(
                child: SizedBox(width: 360, child: child),
              ),
            ),
          ),
        ),
      );
  BackExtensionPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('back-extension-paint')),
              )
              .painter!
          as BackExtensionPainter;

  testWidgets('exact exercise routing and real playback controls', (
    tester,
  ) async {
    final exercise = ExerciseSeedData.build200PlusExercises().singleWhere(
      (e) => e.name == '45-Degree Back Extension',
    );
    await tester.pumpWidget(host(AnatomyExerciseViewer(exercise: exercise)));
    await tester.pumpAndSettle();
    expect(find.text('Animated technique diagram'), findsOneWidget);
    expect(find.text('Demonstration unavailable'), findsNothing);
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(painter(tester).phase, closeTo(1 / 6, .01));
    await tester.tap(find.text('Pause'));
    final stopped = painter(tester).phase;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).phase, stopped);
    await tester.tap(find.text('Restart'));
    await tester.pump();
    expect(painter(tester).phase, 0);
    await tester.tap(find.text('Speed: 1×'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(painter(tester).phase, closeTo(1 / 12, .01));
    await tester.tap(find.text('Pause'));
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(.5);
    await tester.pump();
    expect(painter(tester).phase, .5);
    await tester.tap(find.text('Hide labels'));
    await tester.pump();
    expect(painter(tester).labels, false);
    await tester.tap(find.text('Restart'));
    await tester.tap(find.text('Speed: 0.5×'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    for (var frame = 1; frame <= 24; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(painter(tester).phase, closeTo((frame / 24) % 1, .001));
    }
    await tester.tap(find.text('Pause'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background and reduced motion stop playback', (tester) async {
    await tester.pumpWidget(host(const BackExtensionDiagram()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final phase = painter(tester).phase;
    await tester.pump(const Duration(seconds: 2));
    expect(painter(tester).phase, phase);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(host(const BackExtensionDiagram(), reduced: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Play'))
          .onPressed,
      isNull,
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(.5);
    await tester.pump();
    expect(painter(tester).phase, .5);
  });

  testWidgets('scrolling diagram outside the viewport pauses it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [BackExtensionDiagram(), SizedBox(height: 2000)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(1000);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    final phase = painter(tester).phase;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).phase, phase);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('hidden tab stops and disposal leaves no ticker', (tester) async {
    await tester.pumpWidget(host(const BackExtensionDiagram()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(host(const BackExtensionDiagram(), enabled: false));
    await tester.pump();
    final phase = painter(tester).phase;
    await tester.pump(const Duration(seconds: 1));
    expect(painter(tester).phase, phase);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed geometry, mobile phase previews and whole-loop sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scene = await BackExtensionScene.load();
    for (var i = 0; i <= 100; i++) {
      expect(
        (scene.shoulder(i / 100) - scene.hip).distance,
        closeTo(scene.torsoLength, .00001),
      );
    }
    expect(scene.shoulder(0), scene.shoulder(1));
    final out = Directory('build/previews/back-extension')
      ..createSync(recursive: true);
    Future<void> capture(GlobalKey key, String name) =>
        tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File('${out.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
    final card = GlobalKey();
    await tester.pumpWidget(
      host(RepaintBoundary(key: card, child: const BackExtensionDiagram())),
    );
    await tester.pumpAndSettle();
    for (final phase in [0.0, .25, .5, .75, 1.0]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(phase);
      await tester.pump();
      await capture(card, 'phase-${(phase * 100).round()}');
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(900, 1000);
    final sheet = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0F14),
          body: RepaintBoundary(
            key: sheet,
            child: Wrap(
              children: [
                for (var i = 0; i <= 24; i++)
                  SizedBox(
                    width: 180,
                    height: 155,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 180,
                          height: 125,
                          child: CustomPaint(
                            painter: BackExtensionPainter(scene, i / 24, false),
                          ),
                        ),
                        Text(
                          '${(i / 24 * 100).round()}%',
                          style: const TextStyle(
                            fontFamily: 'Preview',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(sheet, 'full-loop');
    expect(tester.takeException(), isNull);
  });
}
