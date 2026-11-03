import 'package:flutter/material.dart';

import '../app_config.dart';
import '../screens/licenses_screen.dart';
import '../services/ollama_service.dart';
import '../state/chat_controller.dart';
import '../state/chat_scope.dart';
import '../theme/app_theme.dart';

/// The `Name ⌄` pill in the header: the Ollama model in use, tap to change it.
/// Without an API key it asks for one instead.
class ModelChip extends StatelessWidget {
  const ModelChip({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.maybeOf(context);
    final label = chat == null
        ? 'Cryonis'
        : chat.needsApiKey
        ? 'Add API key'
        : chat.selectedModel ??
              switch (chat.connection) {
                Connection.checking => 'Connecting…',
                Connection.offline => 'Offline',
                Connection.online => 'No models',
              };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: chat == null
          ? null
          : () => chat.needsApiKey
                ? showServerSettings(context)
                : showModelPicker(context),
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: inter(size: 15, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the settings sheet says about a plain-http server address, or null for
/// an address that needs no comment.
@visibleForTesting
({String text, bool blocked})? plainHttpNotice(ServerSecurity security) =>
    switch (security) {
      ServerSecurity.localNetwork => (
        text:
            'Plain http on your local network: prompts and answers are not '
            'encrypted. Use this only on a network you trust.',
        blocked: false,
      ),
      ServerSecurity.exposed => (
        text:
            'Plain http to a server on the internet is blocked. Use an '
            'https address.',
        blocked: true,
      ),
      _ => null,
    };

Future<void> showModelPicker(BuildContext context) =>
    _showSheet(context, const _SheetFrame(title: 'Model', child: _ModelList()));

Future<void> showServerSettings(BuildContext context) => _showSheet(
  context,
  const _SheetFrame(title: 'Ollama API', child: _ServerSettings()),
);

Future<void> _showSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: inter(
                    size: 18,
                    weight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList();

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);

    if (chat.models.isEmpty) {
      final message = switch (chat.connection) {
        Connection.checking => 'Checking Ollama at ${chat.baseUrl}…',
        Connection.offline =>
          chat.connectionError ?? "Can't reach Ollama at ${chat.baseUrl}.",
        Connection.online =>
          isCloudUrl(chat.baseUrl)
              ? 'No free Ollama Cloud models are available right now.'
              : 'No models are installed on this server yet.\n'
                    'Run `ollama pull llama3.2`, then refresh.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppText.body.copyWith(color: AppColors.textDim)),
          const SizedBox(height: 16),
          Row(
            children: [
              _SheetButton(label: 'Refresh', onPressed: chat.refreshModels),
              const SizedBox(width: 10),
              _SheetButton(
                label: 'Server settings',
                secondary: true,
                onPressed: () {
                  final navigator = Navigator.of(context)..pop();
                  showServerSettings(navigator.context);
                },
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final model in chat.models)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              chat.selectModel(model);
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      model,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 15),
                    ),
                  ),
                  if (model == chat.selectedModel)
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.accentStrong,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ServerSettings extends StatefulWidget {
  const _ServerSettings();

  @override
  State<_ServerSettings> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<_ServerSettings> {
  late final TextEditingController _url = TextEditingController(
    text: ChatScope.read(context).baseUrl,
  );
  late final TextEditingController _key = TextEditingController(
    text: ChatScope.read(context).apiKey,
  );
  late final TextEditingController _livekit = TextEditingController(
    text: ChatScope.read(context).livekitSandboxId,
  );
  late final TextEditingController _livekitEndpoint = TextEditingController(
    text: ChatScope.read(context).livekitTokenEndpoint,
  );
  String? _voiceConfigError;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _livekit.dispose();
    _livekitEndpoint.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final chat = ChatScope.read(context);
    try {
      await chat.setLivekitTokenEndpoint(_livekitEndpoint.text);
      if (mounted) setState(() => _voiceConfigError = null);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _voiceConfigError = error.message?.toString());
      }
      return;
    }
    await chat.setLivekitSandboxId(_livekit.text);
    await chat.setServer(url: _url.text, apiKey: _key.text);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);
    final (statusText, statusColor) = switch (chat.connection) {
      Connection.checking => ('Connecting…', AppColors.textDim),
      Connection.online => (
        'Connected · ${chat.models.length} model${chat.models.length == 1 ? '' : 's'}',
        const Color(0xFF5BD68A),
      ),
      Connection.offline => (
        chat.connectionError ?? 'Not connected',
        AppColors.error,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body,
          onSubmitted: (_) => _connect(),
          decoration: _fieldDecoration('Ollama API key'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _SheetButton(
              label: 'Ollama Cloud',
              secondary: true,
              onPressed: () => setState(() => _url.text = cloudOllamaUrl),
            ),
            const SizedBox(width: 10),
            _SheetButton(
              label: 'This Mac',
              secondary: true,
              onPressed: () => setState(() => _url.text = localOllamaUrl()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body,
          onSubmitted: (_) => _connect(),
          decoration: _fieldDecoration(cloudOllamaUrl),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _url,
          builder: (context, value, _) {
            final notice = plainHttpNotice(
              serverSecurity(OllamaService.normalizeBaseUrl(value.text)),
            );
            if (notice == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                notice.text,
                style: AppText.caption.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: notice.blocked
                      ? AppColors.error
                      : const Color(0xFFFFC53D),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          statusText,
          style: AppText.caption.copyWith(color: statusColor, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Text(
          'Live voice calls (LiveKit)',
          style: AppText.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _livekitEndpoint,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body,
          onSubmitted: (_) => _connect(),
          decoration: _fieldDecoration('Production token endpoint (HTTPS)'),
        ),
        const SizedBox(height: 8),
        Text(
          _voiceConfigError ?? 'Recommended for production. The endpoint must authenticate the app user and return LiveKit connection details.',
          style: AppText.caption.copyWith(
            fontSize: 13,
            color: _voiceConfigError == null
                ? AppColors.textDim
                : AppColors.error,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _livekit,
          autocorrect: false,
          enableSuggestions: false,
          style: AppText.body,
          onSubmitted: (_) => _connect(),
          decoration: _fieldDecoration('LiveKit sandbox ID'),
        ),
        const SizedBox(height: 10),
        Text(
          chat.usesProductionVoiceEndpoint
              ? 'Voice calls use your production token endpoint.'
              : chat.voiceAgentConfigured
              ? 'Voice calls use the LiveKit development sandbox.'
              : 'Not set: the voice screen uses on-device dictation. Paste the ID from '
                    'LiveKit Cloud → Settings → Token server (development only).',
          style: AppText.caption.copyWith(
            fontSize: 13,
            color: chat.voiceAgentConfigured
                ? const Color(0xFF5BD68A)
                : AppColors.textDim,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ollama Cloud (https://ollama.com) is the main server and uses the API key. '
          'The key is stored on this device and only sent to https addresses.\n\n'
          'Running a model on your own computer is the alternative, with no key:\n'
          'iOS simulator / macOS   http://localhost:11434\n'
          'Android emulator   http://10.0.2.2:11434\n'
          'Physical phone   http://<your Mac\'s IP>:11434\n'
          '(start Ollama with OLLAMA_HOST=0.0.0.0)',
          style: AppText.caption.copyWith(height: 1.6),
        ),
        const SizedBox(height: 18),
        _SheetButton(label: 'Save & connect', onPressed: _connect),
        const SizedBox(height: 10),
        _SheetButton(
          label: 'Open-source licences',
          secondary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LicensesScreen()),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: AppText.body.copyWith(color: AppColors.textDim),
    filled: true,
    fillColor: AppColors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: secondary ? null : AppGradients.mic,
          color: secondary ? AppColors.surface2 : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: inter(
            size: 14,
            weight: FontWeight.w600,
            color: secondary ? AppColors.text : AppColors.onAccent,
          ),
        ),
      ),
    );
  }
}
