import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'secrets.dart';
import 'services/api_key_store.dart';
import 'services/app_licenses.dart';
import 'services/conversation_store.dart';
import 'services/ollama_service.dart';
import 'state/chat_controller.dart';
import 'state/chat_scope.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicenses();
  final prefs = await SharedPreferences.getInstance();
  final apiKeyStore = ApiKeyStore(PlatformSecretStore());
  final savedApiKey = await apiKeyStore.loadAndMigrate(prefs);
  final chat = ChatController(
    service: OllamaService(
      baseUrl: ChatController.savedBaseUrl(prefs),
      // A source-file key is convenient for local development but must never
      // be compiled into a release binary.
      apiKey: savedApiKey ?? (kReleaseMode ? '' : ollamaApiKey),
    ),
    prefs: prefs,
    apiKeyStore: apiKeyStore,
    conversationStore: ConversationStore(
      prefs,
      imagesDirectory: await _imagesDirectory(),
    ),
    livekitSandboxId: livekitSandboxId,
  );
  runApp(CryonisApp(controller: chat));
}

/// Where attached pictures are kept: the app's private support folder, not the
/// preferences. Null if the platform has none, in which case they stay inline.
Future<Directory?> _imagesDirectory() async {
  try {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/chat_images');
  } on Object catch (error) {
    debugPrint('No folder for chat images, keeping them in preferences: $error');
    return null;
  }
}

class CryonisApp extends StatefulWidget {
  const CryonisApp({super.key, required this.controller});

  final ChatController controller;

  @override
  State<CryonisApp> createState() => _CryonisAppState();
}

class _CryonisAppState extends State<CryonisApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.refreshModels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Leaving the app is the moment the system may stop it; make sure the
  /// conversation's queued writes are finished while the app can still run.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'Cryonis',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
