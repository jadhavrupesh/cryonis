import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/screens/agent_voice_screen.dart';
import 'package:cryonis/services/voice_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_voice_backend.dart';

const _hello = VoiceLine(id: '1', fromUser: true, text: 'Hello there');
const _reply = VoiceLine(id: '2', fromUser: false, text: 'Hi! How can I help?');

/// Opens the call screen from a button and records what it pops with.
class _Harness {
  _Harness(this.backends);

  final List<FakeVoiceBackend> backends;
  Object? result = 'not popped';
  int created = 0;

  Widget get app => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<List<ChatMessage>>(
                MaterialPageRoute(
                  builder: (_) => AgentVoiceScreen(
                    createBackend: () => backends[created++ % backends.length],
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app);
    await tester.tap(find.text('open'));
    await _settle(tester);
  }
}

/// The ring animates forever, so `pumpAndSettle` would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets(
    'starts the call and follows the agent: connecting → listening → thinking → speaking',
    (tester) async {
      final backend = FakeVoiceBackend();
      await _Harness([backend]).open(tester);

      expect(backend.started, isTrue);
      expect(find.text('Connecting...', findRichText: true), findsOneWidget);

      backend.emit(phase: AgentPhase.listening);
      await _settle(tester);
      expect(find.text("I'm Listening...", findRichText: true), findsOneWidget);

      // Once words arrive the big caption gives way to the transcript and a
      // small status label.
      backend.emit(phase: AgentPhase.thinking, lines: [_hello]);
      await _settle(tester);
      expect(find.text('Hello there', findRichText: true), findsOneWidget);
      expect(find.text('Thinking'), findsOneWidget);

      backend.emit(
        phase: AgentPhase.speaking,
        lines: [_hello, _reply],
        level: 0.8,
      );
      await _settle(tester);
      expect(
        find.text('Hi! How can I help?', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Speaking'), findsOneWidget);
    },
  );

  testWidgets('shows the latest turn, joining its segments', (tester) async {
    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      lines: [
        _hello,
        _reply,
        const VoiceLine(id: '3', fromUser: true, text: 'Tell me'),
        const VoiceLine(id: '4', fromUser: true, text: 'a fact'),
      ],
    );
    await _Harness([backend]).open(tester);

    expect(find.text('Tell me a fact', findRichText: true), findsOneWidget);
    expect(find.text('Hello there', findRichText: true), findsNothing);
    expect(find.text('Hi! How can I help?', findRichText: true), findsNothing);
    expect(find.text('Listening'), findsOneWidget);
  });

  testWidgets('the mic button mutes and unmutes', (tester) async {
    final backend = FakeVoiceBackend(phase: AgentPhase.listening);
    await _Harness([backend]).open(tester);

    await tester.tap(find.byTooltip('Mute microphone'));
    await _settle(tester);
    expect(backend.micEnabled, isFalse);
    expect(find.text('Mic is muted'), findsOneWidget);

    await tester.tap(find.byTooltip('Unmute microphone'));
    await _settle(tester);
    expect(backend.micEnabled, isTrue);
    expect(find.text("I'm Listening...", findRichText: true), findsOneWidget);
  });

  testWidgets('a failure is shown instead of the status', (tester) async {
    final backend = FakeVoiceBackend();
    await _Harness([backend]).open(tester);

    backend.emit(
      error: 'LiveKit did not accept the sandbox ID (HTTP 404). Check it in the server settings.',
    );
    await _settle(tester);

    expect(
      find.textContaining('did not accept the sandbox ID'),
      findsOneWidget,
    );
    expect(find.text('Connecting...', findRichText: true), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Try again disposes the failed call and starts a fresh one', (
    tester,
  ) async {
    final first = FakeVoiceBackend();
    final second = FakeVoiceBackend(phase: AgentPhase.listening);
    final harness = _Harness([first, second]);
    await harness.open(tester);

    first.emit(error: 'Connection failed.');
    await _settle(tester);
    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(first.endCalls, 1);
    expect(first.disposed, isTrue);
    expect(second.started, isTrue);
    expect(harness.created, 2);
    expect(find.text("I'm Listening...", findRichText: true), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('an unexpected start exception is shown and can be retried', (
    tester,
  ) async {
    final failed = FakeVoiceBackend(startError: StateError('plugin exploded'));
    final replacement = FakeVoiceBackend(phase: AgentPhase.listening);
    await _Harness([failed, replacement]).open(tester);

    expect(find.textContaining("Couldn't start the call"), findsOneWidget);
    expect(find.textContaining('plugin exploded'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await _settle(tester);
    expect(replacement.started, isTrue);
    expect(find.text("I'm Listening...", findRichText: true), findsOneWidget);
  });

  testWidgets('a microphone exception is handled and offers retry', (
    tester,
  ) async {
    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      micError: StateError('permission changed'),
    );
    await _Harness([backend]).open(tester);

    await tester.tap(find.byTooltip('Mute microphone'));
    await _settle(tester);

    expect(
      find.textContaining("Couldn't update the microphone"),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('"continue in chat" ends the call and returns the merged turns', (
    tester,
  ) async {
    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      lines: const [
        _hello,
        VoiceLine(id: '1b', fromUser: true, text: 'what is Flutter?'),
        _reply,
      ],
    );
    final harness = _Harness([backend]);
    await harness.open(tester);

    await tester.tap(find.byTooltip('Type instead'));
    await _settle(tester);

    expect(backend.ended, isTrue);
    final turns = harness.result as List<ChatMessage>;
    expect(turns.map((m) => (m.role, m.content)), [
      (ChatRole.user, 'Hello there what is Flutter?'),
      (ChatRole.assistant, 'Hi! How can I help?'),
    ]);
    expect(
      find.text('open'),
      findsOneWidget,
      reason: 'back on the previous screen',
    );
  });

  testWidgets(
    '"continue in chat" does nothing until there is something to continue',
    (tester) async {
      final backend = FakeVoiceBackend(phase: AgentPhase.listening);
      final harness = _Harness([backend]);
      await harness.open(tester);

      await tester.tap(find.byTooltip('Type instead'));
      await _settle(tester);

      expect(backend.ended, isFalse);
      expect(harness.result, 'not popped');
    },
  );

  testWidgets('ending voice returns the transcript for text chat', (
    tester,
  ) async {
    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      lines: [_hello, _reply],
    );
    final harness = _Harness([backend]);
    await harness.open(tester);

    await tester.tap(find.byTooltip('End voice and continue in chat'));
    await _settle(tester);

    expect(backend.endCalls, 1);
    final turns = harness.result as List<ChatMessage>;
    expect(turns.map((message) => (message.role, message.content)), [
      (ChatRole.user, 'Hello there'),
      (ChatRole.assistant, 'Hi! How can I help?'),
    ]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an end exception does not trap the user on the call screen', (
    tester,
  ) async {
    final backend = FakeVoiceBackend(
      phase: AgentPhase.listening,
      endError: StateError('already disconnected'),
    );
    final harness = _Harness([backend]);
    await harness.open(tester);

    await tester.tap(find.byTooltip('End voice and continue in chat'));
    await _settle(tester);

    expect(backend.endCalls, 1);
    expect(harness.result, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  test('conversationFrom merges consecutive segments and drops empty ones', () {
    final turns = conversationFrom(const [
      VoiceLine(id: 'a', fromUser: true, text: ' one '),
      VoiceLine(id: 'b', fromUser: true, text: 'two'),
      VoiceLine(id: 'c', fromUser: false, text: ''),
      VoiceLine(id: 'd', fromUser: false, text: 'answer'),
      VoiceLine(id: 'e', fromUser: true, text: 'three'),
    ]);

    expect(turns.map((m) => (m.role, m.content)), [
      (ChatRole.user, 'one two'),
      (ChatRole.assistant, 'answer'),
      (ChatRole.user, 'three'),
    ]);
  });
}
