import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/data/exercise_seed_data.dart';
import 'package:tp1/models/exercise_demonstration.dart';
import 'package:tp1/widgets/exercise_3d_viewer.dart';

class RetryBundle extends CachingAssetBundle {
  int attempts = 0;
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (++attempts == 1) throw const FormatException('missing asset');
    return rootBundle.loadString(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use an installed font for readable local QA, without redistributing it.
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader('Preview')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final exercises = ExerciseSeedData.build200PlusExercises();

  test('placeholder files contain no mesh, skin or animation data', () {
    final files = [
      ...Directory('assets/models').listSync().whereType<File>(),
      ...Directory('assets/animations').listSync().whereType<File>(),
    ].where((f) => f.path.endsWith('.glb')).toList();
    expect(files.length, 15);
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(0, Endian.little), 0x46546c67);
      expect(data.getUint32(4, Endian.little), 2);
      expect(data.getUint32(8, Endian.little), bytes.length);
      final length = data.getUint32(12, Endian.little);
      final json = jsonDecode(
        utf8.decode(bytes.sublist(20, 20 + length)),
      ) as Map<String, dynamic>;
      for (final key in ['meshes', 'skins', 'animations', 'buffers']) {
        expect(json[key] ?? [], isEmpty, reason: '${file.path}: $key');
      }
    }
  });

  test(
    'catalog never advertises placeholder animations or substitute clips',
    () {
      expect(
        exercises.every((e) => !e.has3dAnimation && e.glbAssetPath == null),
        isTrue,
      );
      expect(ExerciseSeedData.resolveAnimationGlbPath('unknown'), isNull);
      expect(
        exercises
            .firstWhere((e) => e.name == 'Seated Leg Extension Machine')
            .movementPattern,
        'leg_extension',
      );
      expect(
        exercises
            .firstWhere((e) => e.name == 'Seated Leg Curl Machine')
            .movementPattern,
        'leg_curl_seated',
      );
      expect(
        exercises
            .firstWhere((e) => e.name == 'Lying Prone Leg Curl Machine')
            .movementPattern,
        'leg_curl_prone',
      );
    },
  );

  testWidgets('all 15 exact variants show honest states on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = await ExerciseDemonstrationCatalog.load();
    expect(catalog, hasLength(15));
    final output = Directory('build/previews/avatar-repair')
      ..createSync(recursive: true);
    for (final width in [360.0, 430.0]) {
      tester.view.physicalSize = Size(width, 1200);
      for (var index = 0; index < catalog.length; index++) {
        final guide = catalog[index];
        final exercise = exercises.singleWhere(
          (e) => e.name == guide.exerciseName && e.equipment == guide.equipment,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'Preview',
              ),
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1200),
                disableAnimations: true,
                textScaler: TextScaler.linear(width == 430 ? 1.4 : 1),
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFF0B0F14),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: RepaintBoundary(
                      key: key,
                      child: Exercise3DViewer(exercise: exercise),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Demonstration unavailable'), findsNothing);
        expect(find.text('ANIMATED TECHNIQUE DIAGRAM'), findsOneWidget);
        expect(find.text(guide.equipmentParts.first), findsOneWidget);
        expect(find.text('GLB 2.0 READY'), findsNothing);
        expect(find.byType(Slider), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        expect(
          tester.takeException(),
          isNull,
          reason: '${guide.exerciseName} at $width',
        );
        if (width == 360) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            File('${output.path}/${index.toString().padLeft(2, '0')}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
    }
  });

  testWidgets('failed guide load retries and does not start animation', (
    tester,
  ) async {
    final bundle = RetryBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnatomyExerciseViewer(
              exercise: exercises.first,
              guideBundle: bundle,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Equipment details could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Retry equipment details'));
    await tester.pumpAndSettle();
    expect(bundle.attempts, 2);
    expect(find.text('Equipment for this variation'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('unknown ID does not silently display a squat', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnatomyExerciseViewer(exerciseId: 'missing-exercise'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select an exercise'), findsOneWidget);
    expect(find.text('Barbell Back Squat'), findsNothing);
  });

  testWidgets('same pattern does not borrow another variants guide', (
    tester,
  ) async {
    final incline = exercises.singleWhere(
      (e) => e.name == 'Incline Barbell Bench Press',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnatomyExerciseViewer(exercise: incline)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('this exact variation'), findsOneWidget);
    expect(find.text('Flat bench'), findsNothing);
  });
}
