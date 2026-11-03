// Runs inside the real (sandboxed) app on a device, with the real network:
//
//   flutter test integration_test/native_chat_test.dart -d macos
//
// It sends ONE short message to Ollama Cloud with the key from lib/secrets.dart
// (a free model, so it uses a little of the free quota) and checks the answer
// and its rendering. It also writes a PNG of the screen to the system temp
// directory and prints the path.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cryonis/app_config.dart';
import 'package:cryonis/main.dart';
import 'package:cryonis/secrets.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real chat on Ollama Cloud, shown in the native app', (tester) async {
    final chat = ChatController(
      service: OllamaService(baseUrl: cloudOllamaUrl, apiKey: ollamaApiKey),
      prefs: await SharedPreferences.getInstance(),
    );
    final screen = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(key: screen, child: CryonisApp(controller: chat)));

    Future<void> waitFor(String what, bool Function() done,
        {Duration timeout = const Duration(seconds: 120)}) async {
      final deadline = DateTime.now().add(timeout);
      while (!done()) {
        if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> saveScreen(String name) async {
      final boundary = screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      final file = File('${Directory.systemTemp.path}/$name.png')
        ..writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('SCREENSHOT ${file.path}');
    }

    // The app starts on Ollama Cloud, lists only the free models and picks one.
    await waitFor('the model list', () => chat.connection != Connection.checking);
    expect(chat.connection, Connection.online, reason: chat.connectionError);
    expect(chat.models, isNotEmpty);
    expect(chat.models.toSet().difference(freeCloudModels), isEmpty, reason: 'only free models');
    expect(chat.selectedModel, isNotNull);
    // ignore: avoid_print
    print('MODEL ${chat.selectedModel} of ${chat.models}');
    await saveScreen('cryonis_home');

    // Send a real message from the home screen.
    await tester.enterText(
      find.byType(TextField).first,
      'In two short sentences, explain Python list comprehensions, then show a small python code example.',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 400));

    await waitFor('the answer', () => chat.messages.length == 2 && !chat.isStreaming);
    await tester.pump(const Duration(milliseconds: 600));

    final answer = chat.messages.last;
    expect(answer.isError, isFalse, reason: answer.content);
    expect(answer.content.trim(), isNotEmpty);
    // ignore: avoid_print
    print('ANSWER (${answer.content.length} chars): ${answer.content.replaceAll('\n', ' ⏎ ')}');

    expect(find.byTooltip('Regenerate'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsWidgets);
    await saveScreen('cryonis_chat');
  });
}
