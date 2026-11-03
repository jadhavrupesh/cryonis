import 'dart:convert';

import 'package:cryonis/main.dart';
import 'package:cryonis/screens/licenses_screen.dart';
import 'package:cryonis/services/app_licenses.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ollama.dart';

class _TextBundle extends CachingAssetBundle {
  _TextBundle(this.text);

  final String text;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Inter licence is bundled with the app', () async {
    final text = await rootBundle.loadString(interLicenseAsset);

    expect(text, contains('The Inter Project Authors'));
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
  });

  test('the app licence bundled with the app is the MIT licence', () async {
    final text = await rootBundle.loadString(appLicenseAsset);

    expect(text, startsWith('MIT License'));
    expect(text, contains('Copyright (c) 2026 Rupesh Jadhav'));
  });

  test('registers the Inter licence for the licences page', () async {
    LicenseRegistry.reset();
    registerAppLicenses(
      bundle: _TextBundle('Font notice\n\nSIL OPEN FONT LICENSE'),
    );

    final entries = await LicenseRegistry.licenses.toList();

    expect(entries, hasLength(1));
    expect(entries.single.packages, ['Inter (font)']);
    final paragraphs = entries.single.paragraphs.map((p) => p.text);
    expect(paragraphs.join('\n'), contains('SIL OPEN FONT LICENSE'));
  });

  testWidgets('settings shows the MIT licence first, third-party behind it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final chat = ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => fakeOllama(tokens: const ['ok']),
      ),
      prefs: await SharedPreferences.getInstance(),
    );
    addTearDown(chat.dispose);
    // Wide enough that the test font's wide letters do not overflow the
    // settings sheet's button row (a test-only artifact).
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CryonisApp(controller: chat));
    // The home screen animates forever, so settle by hand.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.byTooltip('Server settings'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final button = find.text('Open-source licences');
    await tester.ensureVisible(button);
    await tester.tap(button);
    // Let the screen build and start reading the licence...
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // ...then give the read real time: the test clock never completes it.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Cryonis's own licence comes first, without the long third-party list.
    expect(find.byType(LicensesScreen), findsOneWidget);
    expect(find.text('MIT License'), findsOneWidget);
    expect(
      find.textContaining('Copyright (c) 2026 Rupesh Jadhav'),
      findsOneWidget,
    );
    expect(find.textContaining('Permission is hereby granted'), findsOneWidget);
    expect(find.byType(LicensePage), findsNothing);

    await tester.tap(find.text('Third-party licences'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(LicensePage), findsOneWidget);
    expect(
      find.textContaining('Released under the MIT License'),
      findsOneWidget,
    );
  });
}
