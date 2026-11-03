// Renders the main screens inside the real app and saves PNGs, so the design can
// be reviewed without a phone or a live call. No network or key needed.
//
//   flutter test integration_test/voice_ui_preview_test.dart -d macos
//
// It prints the PNG paths (in the app's sandbox container temp folder).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryonis/main.dart';
import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/screens/agent_voice_screen.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/services/voice_backend.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:cryonis/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fake_ollama.dart';
import '../test/fake_voice_backend.dart';

const _question =
    'Create a mystical, fantasy-style warrior standing on a cliff during '
    'sunset. What does the scene look like, and what emotions does it convey?';
const _answer =
    'The warrior stands tall, silhouetted against the blazing orange and '
    'purple sky. His cloak billows in the wind, glowing faintly with arcane '
    'runes. The cliff beneath his feet crumbles slightly, adding tension to '
    'the moment.';

const _techQuestion = 'How does a voice call with Cryo work?';
const _techAnswer =
    'A call is a loop of four steps:\n\n'
    '1. **Listen** – your microphone streams to LiveKit Cloud.\n'
    '2. **Understand** – speech-to-text turns it into words.\n'
    '3. **Think** – the language model writes the reply.\n'
    '4. **Speak** – text-to-speech streams the answer back.\n\n'
    'On the app side it is only a few lines:\n\n'
    '```dart\n'
    'final room = Room();\n'
    'await room.connect(url, token);\n'
    'final me = room.localParticipant;\n'
    'await me?.setMicrophoneEnabled(true);\n'
    '```';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screens in every state', (tester) async {
    final boundary = GlobalKey();

    Future<void> mount(Widget app, {double width = 390, double height = 844}) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: RepaintBoundary(key: boundary, child: app),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> save(String name, {int frames = 40}) async {
      // Let animations (ring, glow, word reveal) settle on the new state.
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final object =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => object.toImage(pixelRatio: 2));
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      final file = File('${Directory.systemTemp.path}/ui_$name.png')
        ..writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('PREVIEW ${file.path}');
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: prefs,
    );
    addTearDown(chat.dispose);

    // Home, first run.
    await mount(CryonisApp(controller: chat));
    await save('01_home');

    // Home with a previous conversation, then the chat.
    chat.addConversation(const [
      ChatMessage(role: ChatRole.user, content: _question),
      ChatMessage(role: ChatRole.assistant, content: _answer),
    ]);
    await mount(CryonisApp(controller: chat));
    await save('02_home_previous');

    await tester.tap(find.textContaining('Create a mystical'));
    await save('03_chat', frames: 20);

    // A chat with a list and a code block (used in the README). Start from an
    // empty chat: adding a conversation appends to the one that is open.
    chat.reset();
    chat.addConversation(const [
      ChatMessage(role: ChatRole.user, content: _techQuestion),
      ChatMessage(role: ChatRole.assistant, content: _techAnswer),
    ]);
    // A fresh key each time so the app starts again on the home screen.
    await mount(CryonisApp(key: UniqueKey(), controller: chat));
    // The home screen fades its rows in; wait for them before tapping.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.textContaining('How does a voice call'));
    await save('14_chat_markdown', frames: 20);

    // The server-settings sheet, then the licences screen behind its button.
    await mount(CryonisApp(key: UniqueKey(), controller: chat));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip('Server settings'));
    await save('15_settings', frames: 20);

    final licences = find.text('Open-source licences');
    await tester.ensureVisible(licences);
    await tester.tap(licences);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The test clock never completes an asset read; give it real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await save('16_licences', frames: 20);

    // The live voice screen in each state.
    var backend = FakeVoiceBackend();
    Future<void> voice() => mount(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // A fresh key so each mount builds a new screen state.
        home: AgentVoiceScreen(key: UniqueKey(), createBackend: () => backend),
      ),
    );

    await voice();
    await save('04_voice_connecting');

    backend.emit(phase: AgentPhase.listening, level: 0.35);
    await save('05_voice_listening');

    backend.emit(
      phase: AgentPhase.listening,
      level: 0.6,
      lines: const [
        VoiceLine(id: '1', fromUser: true, text: 'Create a mystical, fantasy-style warrior'),
      ],
    );
    await save('06_voice_words_arriving', frames: 8);
    await save('07_voice_words_settled');

    backend.emit(
      phase: AgentPhase.listening,
      level: 0.5,
      lines: const [VoiceLine(id: '1', fromUser: true, text: _question)],
    );
    await save('08_voice_full_sentence');

    backend.emit(phase: AgentPhase.thinking, level: 0.1, lines: const [
      VoiceLine(id: '1', fromUser: true, text: _question),
    ]);
    await save('09_voice_thinking');

    backend.emit(
      phase: AgentPhase.speaking,
      level: 0.9,
      lines: const [
        VoiceLine(id: '1', fromUser: true, text: _question),
        VoiceLine(id: '2', fromUser: false, text: 'The warrior stands tall, silhouetted against the blazing orange and purple sky.'),
      ],
    );
    await save('10_voice_speaking');

    await backend.setMicEnabled(false);
    backend.emit(phase: AgentPhase.listening, level: 0, lines: const []);
    await save('11_voice_muted');

    await backend.setMicEnabled(true);
    backend.emit(
      error: 'LiveKit did not accept the sandbox ID (HTTP 404). Check it in the server settings.',
    );
    await save('12_voice_failed');

    // The full desktop window.
    backend = FakeVoiceBackend(
      phase: AgentPhase.speaking,
      lines: const [VoiceLine(id: '1', fromUser: false, text: 'The capital of France is Paris.')],
    );
    await mount(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: AgentVoiceScreen(key: UniqueKey(), createBackend: () => backend),
      ),
      width: 1000,
      height: 700,
    );
    backend.emit(level: 0.8);
    await save('13_voice_wide_window');
  });
}
