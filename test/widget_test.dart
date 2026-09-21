import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arrowescape/core/constants.dart';
import 'package:arrowescape/widgets/lives_bar.dart';

void main() {
  testWidgets('LivesBar renders one heart per max life', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LivesBar(lives: 3, maxLives: AppConstants.maxLives),
          ),
        ),
      ),
    );
    await tester.pump();

    // Each full heart renders 2 stacked favorite icons (shadow + main).
    expect(
      find.byIcon(Icons.favorite),
      findsNWidgets(AppConstants.maxLives * 2),
    );
  });

  testWidgets('LivesBar shows empty hearts for lost lives', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LivesBar(lives: 1, maxLives: AppConstants.maxLives),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
  });
}
