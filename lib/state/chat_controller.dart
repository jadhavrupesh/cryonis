import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/chat_message.dart';
import '../services/api_key_store.dart';
import '../services/ollama_service.dart';

enum Connection { checking, online, offline }

/// Owns the conversation, the Ollama connection and the model selection.
class ChatController extends ChangeNotifier {
  ChatController({
    required this._service,
    required this._prefs,
    ApiKeyStore? apiKeyStore,
    String livekitSandboxId = '',
    String livekitTokenEndpoint = '',
  }) : _selectedModel = _prefs.getString(_modelKey),
       _apiKeyStore = apiKeyStore ?? ApiKeyStore(MemorySecretStore()),
       _livekitSandboxId = _prefs.getString(_livekitKey) ?? livekitSandboxId,
       _livekitTokenEndpoint = _validTokenEndpoint(
         _prefs.getString(_livekitTokenEndpointKey) ?? livekitTokenEndpoint,
       ) {
    _restoreConversation();
  }

  static const _hostKey = 'ollama_host';
  static const _modelKey = 'ollama_model';
  static const _livekitKey = 'livekit_sandbox_id';
  static const _livekitTokenEndpointKey = 'livekit_token_endpoint';
  static const conversationKey = 'chat_messages_v1';
  static const activityKey = 'chat_last_activity_v1';

  /// Reads the saved server address, falling back to the platform default.
  static String savedBaseUrl(SharedPreferences prefs) =>
      prefs.getString(_hostKey) ?? defaultOllamaUrl();

  final OllamaService _service;
  final SharedPreferences _prefs;
  final ApiKeyStore _apiKeyStore;

  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _subscription;

  List<String> _models = const [];
  String? _selectedModel;
  Connection _connection = Connection.checking;
  String? _connectionError;

  UnmodifiableListView<ChatMessage> get messages =>
      UnmodifiableListView(_messages);
  bool get hasConversation => _messages.isNotEmpty;

  /// When the saved conversation last changed, for the "previous" list.
  DateTime? get lastActivity => _lastActivity;
  DateTime? _lastActivity;
  List<String> get models => _models;
  String? get selectedModel => _selectedModel;
  Connection get connection => _connection;
  String? get connectionError => _connectionError;
  String get baseUrl => _service.baseUrl;
  String get apiKey => _service.apiKey ?? '';

  String _livekitSandboxId;
  String _livekitTokenEndpoint;

  /// LiveKit Cloud token-server ID for live voice calls with the voice agent.
  String get livekitSandboxId => _livekitSandboxId;

  /// Application-owned HTTPS token endpoint used instead of the development
  /// sandbox whenever it is configured.
  String get livekitTokenEndpoint => _livekitTokenEndpoint;

  /// Live voice calls need the LiveKit sandbox ID; without it the voice screen
  /// falls back to on-device dictation.
  bool get voiceAgentConfigured =>
      _livekitTokenEndpoint.isNotEmpty || _livekitSandboxId.trim().isNotEmpty;

  bool get usesProductionVoiceEndpoint => _livekitTokenEndpoint.isNotEmpty;

  Future<void> setLivekitTokenEndpoint(String endpoint) async {
    final clean = endpoint.trim();
    if (clean.isNotEmpty && _validTokenEndpoint(clean).isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Enter an absolute HTTPS URL without credentials or a fragment.',
      );
    }
    _livekitTokenEndpoint = clean;
    if (clean.isEmpty) {
      await _prefs.remove(_livekitTokenEndpointKey);
    } else {
      await _prefs.setString(_livekitTokenEndpointKey, clean);
    }
    notifyListeners();
  }

  Future<void> setLivekitSandboxId(String id) async {
    _livekitSandboxId = id.trim();
    if (_livekitSandboxId.isEmpty) {
      await _prefs.remove(_livekitKey);
    } else {
      await _prefs.setString(_livekitKey, _livekitSandboxId);
    }
    notifyListeners();
  }

  static String _validTokenEndpoint(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '';
    final uri = Uri.tryParse(clean);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return '';
    }
    return clean;
  }

  bool get isStreaming => _subscription != null;

  /// True while we are waiting for the first token of the current reply.
  bool get isWorking =>
      isStreaming && _messages.isNotEmpty && _messages.last.content.isEmpty;

  /// The hosted API is the primary server and cannot be used without a key.
  bool get needsApiKey => isCloudUrl(baseUrl) && apiKey.isEmpty;

  Future<void> refreshModels() async {
    if (needsApiKey) {
      _models = const [];
      _connection = Connection.offline;
      _connectionError =
          'Add your Ollama API key in the server settings to '
          'use Ollama Cloud.';
      notifyListeners();
      return;
    }

    _connection = Connection.checking;
    notifyListeners();
    try {
      final installed = await _service.listModels();
      // The hosted API lists paid models too; with the API key only the free
      // ones are offered.
      _models = isCloudUrl(baseUrl)
          ? installed.where(freeCloudModels.contains).toList()
          : installed;
      _connection = Connection.online;
      _connectionError = null;
      if (!_models.contains(_selectedModel)) {
        _selectedModel =
            preferredModels.where(_models.contains).firstOrNull ??
            _models.firstOrNull;
      }
    } on OllamaException catch (e) {
      _models = const [];
      _connection = Connection.offline;
      _connectionError = e.message;
    }
    notifyListeners();
  }

  void selectModel(String model) {
    _selectedModel = model;
    _prefs.setString(_modelKey, model);
    notifyListeners();
  }

  /// Points the app at another Ollama server (local, LAN or the hosted API
  /// at https://ollama.com) and reloads its models.
  Future<void> setServer({required String url, String apiKey = ''}) async {
    final key = apiKey.trim();
    _service.baseUrl = url;
    _service.apiKey = key.isEmpty ? null : key;
    await _prefs.setString(_hostKey, _service.baseUrl);
    await _apiKeyStore.save(key);
    // Remove any pre-secure-storage value left by an older app build.
    await _prefs.remove(ApiKeyStore.key);
    await refreshModels();
  }

  void send(String text, {List<ChatImage> images = const []}) {
    final prompt = text.trim();
    if ((prompt.isEmpty && images.isEmpty) || isStreaming) return;
    _messages.add(
      ChatMessage(
        role: ChatRole.user,
        content: prompt,
        images: List.unmodifiable(images),
      ),
    );
    _persistConversation();
    _respond();
  }

  /// Re-asks the last question after a failed reply.
  void retry() {
    if (_messages.isEmpty || !_messages.last.isError) return;
    regenerate();
  }

  /// Throws away the last answer and asks the model again.
  void regenerate() {
    if (isStreaming ||
        _messages.isEmpty ||
        _messages.last.role != ChatRole.assistant) {
      return;
    }
    _messages.removeLast();
    _persistConversation();
    _respond();
  }

  /// Adds the turns of a finished voice call so the chat can carry on from it.
  void addConversation(Iterable<ChatMessage> turns) {
    _messages.addAll(turns.where((m) => m.content.trim().isNotEmpty));
    _persistConversation();
    notifyListeners();
  }

  /// Stops generating but keeps whatever has streamed in so far.
  void stop() {
    if (!isStreaming) return;
    _subscription?.cancel();
    _subscription = null;
    if (_messages.last.content.isEmpty) _messages.removeLast();
    _persistConversation();
    notifyListeners();
  }

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _messages.clear();
    _persistConversation();
    notifyListeners();
  }

  void _respond() {
    final model = _selectedModel;
    if (model == null) {
      _messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          content: _connection == Connection.offline
              ? (_connectionError ?? "Can't reach Ollama.")
              : isCloudUrl(baseUrl)
              ? 'No free Ollama Cloud models are available right now.'
              : 'No model installed yet. Run `ollama pull llama3.2` on the '
                    'server, then pick it from the model chip.',
          isError: true,
        ),
      );
      _persistConversation();
      notifyListeners();
      return;
    }

    final history = _messages
        .where((m) => !m.isError && m.content.isNotEmpty)
        .toList();
    _messages.add(const ChatMessage(role: ChatRole.assistant, content: ''));
    final index = _messages.length - 1;

    _subscription = _service
        .chat(model: model, messages: history, system: systemPrompt)
        .listen(
          (chunk) {
            _messages[index] = _messages[index].copyWith(
              content: _messages[index].content + chunk,
            );
            notifyListeners();
          },
          onError: (Object error) {
            _subscription = null;
            _fail(index, error is OllamaException ? error.message : '$error');
          },
          onDone: () {
            _subscription = null;
            _persistConversation();
            notifyListeners();
          },
          cancelOnError: true,
        );
    notifyListeners();
  }

  void _fail(int index, String message) {
    // Keep a partial answer, and add the failure as its own message.
    if (_messages[index].content.isEmpty) _messages.removeAt(index);
    _messages.add(
      ChatMessage(role: ChatRole.assistant, content: message, isError: true),
    );
    _persistConversation();
    notifyListeners();
  }

  void _restoreConversation() {
    final saved = _prefs.getString(conversationKey);
    if (saved == null) return;
    final activity = _prefs.getInt(activityKey);
    if (activity != null) {
      _lastActivity = DateTime.fromMillisecondsSinceEpoch(activity);
    }
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! List<dynamic>) throw const FormatException();
      for (final value in decoded) {
        try {
          if (value is Map<String, dynamic>) {
            _messages.add(ChatMessage.fromJson(value));
          }
        } on FormatException {
          // A single corrupt record should not hide the valid conversation.
        } on TypeError {
          // Nested attachment data can also be malformed; skip that record.
        }
      }
    } on FormatException {
      unawaited(_prefs.remove(conversationKey));
    }
  }

  void _persistConversation() {
    if (_messages.isEmpty) {
      _lastActivity = null;
      unawaited(_prefs.remove(conversationKey));
      unawaited(_prefs.remove(activityKey));
      return;
    }
    _lastActivity = DateTime.now();
    unawaited(
      _prefs.setInt(activityKey, _lastActivity!.millisecondsSinceEpoch),
    );
    final stable = _messages.where(
      (message) => message.content.isNotEmpty || message.images.isNotEmpty,
    );
    unawaited(
      _prefs.setString(
        conversationKey,
        jsonEncode([for (final message in stable) message.toJson()]),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
