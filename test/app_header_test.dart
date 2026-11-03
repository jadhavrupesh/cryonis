import 'package:cryonis/widgets/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('works on its own, without a chat controller above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppHeader())),
    );

    expect(find.text('Cryonis'), findsOneWidget);
    expect(find.byTooltip('Server settings'), findsOneWidget);
    expect(find.byTooltip('Check Ollama connection'), findsOneWidget);
    // Nothing to open or check without a controller; tapping must not throw.
    await tester.tap(find.byTooltip('Server settings'));
    await tester.tap(find.byTooltip('Check Ollama connection'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a back arrow instead of the menu when asked to', (
    tester,
  ) async {
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppHeader(onBack: () => backs++)),
      ),
    );

    expect(find.byTooltip('Server settings'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    expect(backs, 1);
  });
}
