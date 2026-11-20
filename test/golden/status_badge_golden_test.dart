import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_rental/core/widgets/status_badge.dart';

import 'golden_config.dart';

void main() {
  useTolerantGoldens('test/golden/status_badge_golden_test.dart');

  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: child),
        ),
      );

  testWidgets('StatusBadge variants match the golden image', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(host(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge.verified(),
          const SizedBox(height: 12),
          StatusBadge.alert(),
          const SizedBox(height: 12),
          const StatusBadge(
            label: 'Pending',
            icon: Icons.schedule_rounded,
            backgroundColor: Color(0xFFFEF3C7),
            contentColor: Color(0xFFB45309),
          ),
        ],
      ),
    ));

    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/status_badge_variants.png'),
    );
  });

  testWidgets('StatusBadge keeps its label when uppercase is off',
      (tester) async {
    await tester.pumpWidget(host(
      const StatusBadge(
        label: 'Paid',
        icon: Icons.check_circle_rounded,
        backgroundColor: Colors.green,
        uppercase: false,
      ),
    ));

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('PAID'), findsNothing);
  });
}
