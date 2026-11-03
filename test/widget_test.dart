import 'package:cryonis/main.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ollama.dart';

/// The avatar orb and voice ring animate forever, so `pumpAndSettle` would never return.
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

/// The test clock never delivers a stream's "done" event, so let it finish in
/// real time before checking what the UI shows for a completed answer.
Future<void> _finishStreaming(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

void main() {
  _quickActionTests();

  testWidgets('home → suggestion → streamed reply → close chat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => fakeOllama(tokens: const ['Sure', ' thing']),
      ),
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(chat.dispose);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    // Home screen from the design.
    expect(find.text('Ask anything'), findsOneWidget);
    expect(find.text('llama3.2:latest'), findsOneWidget); // model pill
    expect(find.text('Previous conversations'), findsNothing);
    expect(find.text('Analyse'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Summarize an article for me');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // Chat screen: user bubble and the streamed assistant reply.
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Summarize an article for me'), findsOneWidget);
    expect(find.text('Sure thing', findRichText: true), findsOneWidget);

    // While the answer streams there are no actions, only a stop button.
    expect(find.byTooltip('Regenerate'), findsNothing);

    // A finished answer offers copy and regenerate.
    await _finishStreaming(tester);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Regenerate'), findsOneWidget);

    await tester.tap(find.byTooltip('Regenerate'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await _finishStreaming(tester);
    expect(find.text('Sure thing', findRichText: true), findsOneWidget);
    expect(chat.messages.map((m) => m.content), [
      'Summarize an article for me',
      'Sure thing',
    ]);

    await tester.tap(find.byTooltip('Back'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // Back home: the conversation is listed, titled by its first message.
    expect(find.text('Ask anything'), findsOneWidget);
    expect(find.text('Previous conversations'), findsOneWidget);
    expect(find.text('Summarize an article for me'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
    expect(chat.messages, isNotEmpty);

    await tester.tap(find.text('Summarize an article for me'));
    await _pumpFor(tester, const Duration(milliseconds: 350));
    expect(find.text('Sure thing', findRichText: true), findsOneWidget);
  });

  testWidgets('shows how to fix an unreachable Ollama server', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => fakeOllama(chatStatus: 500),
      ),
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(chat.dispose);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Summarize an article for me');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    expect(find.text('boom'), findsOneWidget);
    expect(find.text('Tap to retry'), findsOneWidget);
  });
}

void _quickActionTests() {
  testWidgets('a quick-action chip starts the input off and leaves the rest to you', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(chat.dispose);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    await tester.tap(find.text('Summaries'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Summarise ');
    expect(chat.messages, isEmpty, reason: 'a chip never sends anything itself');
  });
}
