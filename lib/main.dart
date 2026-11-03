import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'secrets.dart';
import 'services/api_key_store.dart';
import 'services/app_licenses.dart';
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
    livekitSandboxId: livekitSandboxId,
  );
  runApp(CryonisApp(controller: chat));
}

class CryonisApp extends StatefulWidget {
  const CryonisApp({super.key, required this.controller});

  final ChatController controller;

  @override
  State<CryonisApp> createState() => _CryonisAppState();
}

class _CryonisAppState extends State<CryonisApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.refreshModels();
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
