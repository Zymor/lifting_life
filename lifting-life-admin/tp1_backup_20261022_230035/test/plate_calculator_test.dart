import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/widgets/plate_calculator.dart';

void main() {
  testWidgets('PlateCalculatorDialog renders and calculates 100kg metric barbell load', (tester) async {
    double applied = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                PlateCalculatorDialog.show(
                  context,
                  initialWeight: 100.0,
                  unit: 'kg',
                  onApplyWeight: (w) => applied = w,
                );
              },
              child: const Text('Open Calc'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Calc'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Plate Calculator'), findsOneWidget);
    expect(find.text('BARBELL SLEEVE (ONE SIDE)'), findsOneWidget);
    expect(find.text('100.0 kg'), findsOneWidget);

    // 100kg total with 20kg bar leaves 80kg = 40kg per side (1x 25kg, 1x 15kg)
    expect(find.text('Plates per side: 40.0 kg'), findsOneWidget);
    expect(find.text('Exact loaded: 100.0 kg'), findsOneWidget);

    // Tap apply button
    await tester.tap(find.text('Apply 100.0 kg to Set'));
    await tester.pumpAndSettle();

    expect(applied, 100.0);
    expect(find.text('Barbell Plate Calculator'), findsNothing);
  });

  testWidgets('PlateCalculatorDialog toggles to LBS unit with 45lb Olympic bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                PlateCalculatorDialog.show(
                  context,
                  initialWeight: 225.0,
                  unit: 'lbs',
                );
              },
              child: const Text('Open Calc Lbs'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Calc Lbs'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Plate Calculator'), findsOneWidget);
    expect(find.text('225.0 lbs'), findsOneWidget);

    // 225 lbs with 45 lb bar leaves 180 lbs = 90 lbs per side (2x 45 lbs)
    expect(find.text('Plates per side: 90.0 lbs'), findsOneWidget);
    expect(find.text('Exact loaded: 225.0 lbs'), findsOneWidget);
    expect(find.text('2x 45 lbs'), findsOneWidget);
  });
}

