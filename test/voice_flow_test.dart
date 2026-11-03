import 'package:cryonis/main.dart';
import 'package:cryonis/screens/agent_voice_screen.dart';
import 'package:cryonis/screens/voice_flow.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/services/voice_backend.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ollama.dart';
import 'fake_voice_backend.dart';

/// The ring animates forever, so `pumpAndSettle` would never return.
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  testWidgets('home mic → live call → continue in chat → close chat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: await SharedPreferences.getInstance(),
      livekitSandboxId: 'sandbox-123',
    );
    addTearDown(chat.dispose);

    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      lines: const [
        VoiceLine(id: '1', fromUser: true, text: 'Tell me a fact'),
        VoiceLine(id: '2', fromUser: false, text: 'Honey never spoils.'),
      ],
    );
    VoiceConnection? connectionUsed;
    final original = voiceBackendFactory;
    voiceBackendFactory = (connection) {
      connectionUsed = connection;
      return backend;
    };
    addTearDown(() => voiceBackendFactory = original);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Speak'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // The live call opened with the saved sandbox ID.
    expect(find.byType(AgentVoiceScreen), findsOneWidget);
    expect(connectionUsed?.value, 'sandbox-123');
    expect(connectionUsed?.isProduction, isFalse);
    expect(backend.started, isTrue);

    await tester.tap(find.byTooltip('Type instead'));
    await _pumpFor(tester, const Duration(milliseconds: 600));

    // The call is over and its turns are now an ordinary conversation.
    expect(backend.ended, isTrue);
    expect(find.byType(AgentVoiceScreen), findsNothing);
    expect(chat.messages.map((m) => m.content), [
      'Tell me a fact',
      'Honey never spoils.',
    ]);
    expect(find.text('Tell me a fact'), findsOneWidget);
    expect(
      find.text('Honey never spoils.', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Ask anything'), findsOneWidget);
    expect(find.text('Previous conversations'), findsOneWidget);
    expect(chat.messages, isNotEmpty);
  });

  testWidgets('ending a completed voice call moves its turns to text chat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: await SharedPreferences.getInstance(),
      livekitSandboxId: 'sandbox-123',
    );
    addTearDown(chat.dispose);

    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      lines: const [
        VoiceLine(id: '1', fromUser: true, text: 'Give me a summary'),
        VoiceLine(id: '2', fromUser: false, text: 'Here is the summary.'),
      ],
    );
    final original = voiceBackendFactory;
    voiceBackendFactory = (_) => backend;
    addTearDown(() => voiceBackendFactory = original);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Speak'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('End voice and continue in chat'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    expect(backend.ended, isTrue);
    expect(find.byType(AgentVoiceScreen), findsNothing);
    expect(chat.messages.map((message) => message.content), [
      'Give me a summary',
      'Here is the summary.',
    ]);
    expect(find.text('Give me a summary'), findsOneWidget);
    expect(
      find.text('Here is the summary.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('production token endpoint is preferred over the sandbox', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: await SharedPreferences.getInstance(),
      livekitSandboxId: 'sandbox-fallback',
      livekitTokenEndpoint: 'https://api.example.com/livekit-token',
    );
    addTearDown(chat.dispose);

    final backend = FakeVoiceBackend(phase: AgentPhase.listening);
    VoiceConnection? connectionUsed;
    final original = voiceBackendFactory;
    voiceBackendFactory = (connection) {
      connectionUsed = connection;
      return backend;
    };
    addTearDown(() => voiceBackendFactory = original);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Speak'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    expect(connectionUsed?.value, 'https://api.example.com/livekit-token');
    expect(connectionUsed?.isProduction, isTrue);

    await tester.tap(find.byTooltip('End voice and continue in chat'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    expect(backend.ended, isTrue);
  });
}
