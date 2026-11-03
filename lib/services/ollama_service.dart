import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/chat_message.dart';

class OllamaException implements Exception {
  const OllamaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin client for the Ollama REST API (`/api/tags`, streaming `/api/chat`).
class OllamaService {
  OllamaService({
    required String baseUrl,
    this.apiKey,
    http.Client Function()? clientFactory,
    this.connectionTimeout = const Duration(seconds: 12),
  }) : _baseUrl = normalizeBaseUrl(baseUrl),
       _clientFactory = clientFactory ?? http.Client.new;

  /// A fresh client is created per request so an in-flight chat stream can be
  /// aborted by closing it.
  final http.Client Function() _clientFactory;

  /// Applies while opening a request. A streamed response may continue for
  /// longer after Ollama accepts it.
  final Duration connectionTimeout;

  String _baseUrl;
  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = normalizeBaseUrl(value);

  /// Optional API key, needed for the hosted API at https://ollama.com. A
  /// local server ignores it.
  String? apiKey;

  /// The key is only ever sent over https, so it can't leak in cleartext if
  /// the address is switched to a plain-http LAN server.
  Map<String, String> get _authHeaders {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty || !_baseUrl.startsWith('https://')) {
      return const {};
    }
    return {'Authorization': 'Bearer $key'};
  }

  /// 401 means the key is wrong or missing; other errors (e.g. 402 "not
  /// included in your free usage") carry their own explanation.
  OllamaException _httpError(int status, String body) {
    if (status == 401) {
      return const OllamaException(
        'The server rejected the API key. Check it in the server settings.',
      );
    }
    return OllamaException(_errorFrom(body) ?? 'Ollama returned $status.');
  }

  static String normalizeBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.contains('://')) {
      // An address typed without a scheme gets plain http only where that is
      // acceptable (this device, the local network); anything on the internet
      // gets https.
      url = serverSecurity('http://$url') == ServerSecurity.exposed
          ? 'https://$url'
          : 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Refuses to talk to a plain-http address on the internet: every prompt and
  /// answer would travel unencrypted. Plain http stays available for this
  /// device and the local network, where running Ollama yourself is normal.
  /// (Android's own network policy does not cover Dart's HTTP client, so the
  /// rule has to be enforced here.)
  void _requireSafeAddress() {
    if (serverSecurity(_baseUrl) == ServerSecurity.exposed) {
      throw const OllamaException(
        'Plain http to a server on the internet is blocked, because your '
        'prompts would travel unencrypted. Use an https address in the server '
        'settings.',
      );
    }
  }

  OllamaException _unreachable([Object? cause]) => OllamaException(
    "Can't reach Ollama at $_baseUrl. Check your internet connection, or "
    "that the server is running (`ollama serve`) and the address is correct."
    '${cause == null ? '' : ' (${_describe(cause)})'}',
  );

  /// A short, single-line description of an error for the user.
  static String _describe(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  /// Names of the models installed on the server, e.g. `llama3.2:latest`.
  Future<List<String>> listModels() async {
    _requireSafeAddress();
    final client = _clientFactory();
    try {
      final response = await client
          .get(_uri('/api/tags'), headers: _authHeaders)
          .timeout(connectionTimeout);
      if (response.statusCode != 200) {
        throw _httpError(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models =
          (data['models'] as List<dynamic>? ?? const [])
              .map((m) => (m as Map<String, dynamic>)['name'] as String)
              .toList()
            ..sort();
      return models;
    } on OllamaException {
      rethrow;
    } catch (e) {
      throw _unreachable(e);
    } finally {
      client.close();
    }
  }

  /// Streams the assistant's reply token by token. Cancelling the
  /// subscription closes the connection, which makes Ollama stop generating.
  ///
  /// Built on a [StreamController] rather than `async*` so that a request
  /// failing *after* the listener cancelled (Close chat, Stop, app exit) is
  /// dropped silently instead of surfacing as an unhandled exception.
  Stream<String> chat({
    required String model,
    required List<ChatMessage> messages,
    String? system,
  }) {
    final client = _clientFactory();
    var cancelled = false;
    late final StreamController<String> out;

    Future<void> run() async {
      try {
        _requireSafeAddress();
        final request = http.Request('POST', _uri('/api/chat'))
          ..headers['Content-Type'] = 'application/json'
          ..headers.addAll(_authHeaders)
          ..body = jsonEncode({
            'model': model,
            'stream': true,
            'messages': [
              if (system != null) {'role': 'system', 'content': system},
              for (final m in messages)
                {
                  'role': m.role.name,
                  'content': m.content,
                  if (m.images.isNotEmpty)
                    'images': [for (final image in m.images) image.base64Data],
                },
            ],
          });

        final http.StreamedResponse response;
        try {
          response = await client.send(request).timeout(connectionTimeout);
        } catch (e) {
          throw _unreachable(e);
        }

        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          throw _httpError(response.statusCode, body);
        }

        final lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (cancelled) return;
          if (line.trim().isEmpty) continue;
          final json = jsonDecode(line) as Map<String, dynamic>;
          final error = json['error'];
          if (error is String) throw OllamaException(error);

          final content =
              (json['message'] as Map<String, dynamic>?)?['content'];
          if (content is String && content.isNotEmpty) out.add(content);
          if (json['done'] == true) break;
        }
      } catch (error) {
        if (!cancelled) {
          out.addError(
            error is OllamaException
                ? error
                : OllamaException(
                    'The connection to Ollama was interrupted or it sent an '
                    'unexpected response. (${_describe(error)})',
                  ),
          );
        }
      } finally {
        client.close();
        if (!out.isClosed) unawaited(out.close());
      }
    }

    out = StreamController<String>(
      onListen: () => unawaited(run()),
      onCancel: () {
        cancelled = true;
        client.close();
      },
    );
    return out.stream;
  }

  static String? _errorFrom(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic> && json['error'] is String) {
        return json['error'] as String;
      }
    } catch (_) {}
    return null;
  }
}
