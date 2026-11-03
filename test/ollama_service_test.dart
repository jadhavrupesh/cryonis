import 'dart:async';
import 'dart:convert';

import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

import 'fake_ollama.dart';

const _hi = [ChatMessage(role: ChatRole.user, content: 'hi')];

/// Returns a canned streamed response and reports when it was closed.
class _ClosableClient extends BaseClient {
  _ClosableClient({required this.onClose, required this.response});

  final void Function() onClose;
  final StreamedResponse response;

  @override
  Future<StreamedResponse> send(BaseRequest request) async => response;

  @override
  void close() => onClose();
}

void main() {
  group('normalizeBaseUrl', () {
    test('adds a scheme and strips trailing slashes', () {
      expect(
        OllamaService.normalizeBaseUrl('192.168.1.5:11434/'),
        'http://192.168.1.5:11434',
      );
      expect(
        OllamaService.normalizeBaseUrl(' https://host:1// '),
        'https://host:1',
      );
    });
  });

  group('listModels', () {
    test('returns installed model names sorted', () async {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () =>
            fakeOllama(models: ['qwen2.5:7b', 'llama3.2:latest']),
      );
      expect(await service.listModels(), ['llama3.2:latest', 'qwen2.5:7b']);
    });

    test('reports an unreachable server', () {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () =>
            MockClient((_) async => throw ClientException('refused')),
      );
      expect(
        service.listModels(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            contains("Can't reach"),
          ),
        ),
      );
    });
  });

  group('api key', () {
    test(
      'is sent as a bearer token to https servers, for tags and chat',
      () async {
        final headers = <Map<String, String>>[];
        final service = OllamaService(
          baseUrl: 'https://ollama.com',
          apiKey: ' secret ',
          clientFactory: () => fakeOllama(capturedHeaders: headers),
        );

        await service.listModels();
        await service.chat(model: 'm', messages: _hi).toList();

        expect(headers, hasLength(2));
        for (final h in headers) {
          expect(h['Authorization'], 'Bearer secret');
        }
      },
    );

    test('is never sent over plain http', () async {
      final headers = <Map<String, String>>[];
      final service = OllamaService(
        baseUrl: 'http://192.168.1.5:11434',
        apiKey: 'secret',
        clientFactory: () => fakeOllama(capturedHeaders: headers),
      );

      await service.listModels();
      await service.chat(model: 'm', messages: _hi).toList();

      expect(headers.expand((h) => h.keys), isNot(contains('Authorization')));
    });

    test('a 402 shows the server explanation instead of blaming the key', () {
      final service = OllamaService(
        baseUrl: 'https://ollama.com',
        apiKey: 'good',
        clientFactory: () => fakeOllama(
          chatStatus: 402,
          chatError: 'this model is not included in your free usage',
        ),
      );
      expect(
        service.chat(model: 'kimi-k3', messages: _hi).toList(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            'this model is not included in your free usage',
          ),
        ),
      );
    });

    test('a 401 explains that the key was rejected', () {
      final service = OllamaService(
        baseUrl: 'https://ollama.com',
        apiKey: 'wrong',
        clientFactory: () => fakeOllama(tagsStatus: 401, chatStatus: 401),
      );
      final rejected = throwsA(
        isA<OllamaException>().having(
          (e) => e.message,
          'message',
          contains('API key'),
        ),
      );

      expect(service.listModels(), rejected);
      expect(service.chat(model: 'm', messages: _hi).toList(), rejected);
    });
  });

  group('chat', () {
    test('streams tokens and sends model, history and system prompt', () async {
      final captured = <Map<String, dynamic>>[];
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => fakeOllama(captured: captured),
      );

      final tokens = await service
          .chat(model: 'llama3.2', messages: _hi, system: 'be brief')
          .toList();

      expect(tokens, ['Hello', ' world']);
      expect(captured.single['model'], 'llama3.2');
      expect(captured.single['stream'], true);
      expect(captured.single['messages'], [
        {'role': 'system', 'content': 'be brief'},
        {'role': 'user', 'content': 'hi'},
      ]);
    });

    test(
      'includes base64 image payloads only on messages that have them',
      () async {
        final captured = <Map<String, dynamic>>[];
        final service = OllamaService(
          baseUrl: 'http://localhost:11434',
          clientFactory: () => fakeOllama(captured: captured),
        );
        const image = ChatImage(
          name: 'photo.jpg',
          mimeType: 'image/jpeg',
          base64Data: 'anBlZw==',
        );

        await service
            .chat(
              model: 'vision',
              messages: const [
                ChatMessage(
                  role: ChatRole.user,
                  content: 'describe it',
                  images: [image],
                ),
              ],
            )
            .toList();

        final messages = captured.single['messages'] as List<dynamic>;
        expect(messages.single, {
          'role': 'user',
          'content': 'describe it',
          'images': ['anBlZw=='],
        });
      },
    );

    test('reassembles JSON lines split across network chunks', () async {
      final line = jsonEncode({
        'message': {'role': 'assistant', 'content': 'héllo'},
        'done': false,
      });
      final bytes = utf8.encode('$line\n{"done":true}\n');
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => MockClient.streaming((_, _) async {
          // Cut in the middle of the multi-byte "é" and of the line itself.
          final cut = bytes.indexOf(0xC3) + 1;
          return StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, cut), bytes.sublist(cut)]),
            200,
          );
        }),
      );

      expect(await service.chat(model: 'm', messages: _hi).toList(), ['héllo']);
    });

    test('surfaces the server error for a missing model', () {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () =>
            fakeOllama(chatStatus: 404, chatError: "model 'nope' not found"),
      );
      expect(
        service.chat(model: 'nope', messages: _hi).toList(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('surfaces an error line inside a 200 stream', () {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => MockClient.streaming(
          (_, _) async => StreamedResponse(
            Stream.value(utf8.encode('{"error":"out of memory"}\n')),
            200,
          ),
        ),
      );
      expect(
        service.chat(model: 'm', messages: _hi).toList(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            'out of memory',
          ),
        ),
      );
    });

    test('reports an unreachable server, including the cause', () {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => MockClient.streaming(
          (_, _) async => throw ClientException('refused'),
        ),
      );
      expect(
        service.chat(model: 'm', messages: _hi).toList(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            allOf(contains("Can't reach"), contains('refused')),
          ),
        ),
      );
    });

    test('times out while opening a chat connection', () {
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        connectionTimeout: const Duration(milliseconds: 1),
        clientFactory: () => MockClient.streaming(
          (_, _) => Completer<StreamedResponse>().future,
        ),
      );

      expect(
        service.chat(model: 'm', messages: _hi).toList(),
        throwsA(
          isA<OllamaException>().having(
            (error) => error.message,
            'message',
            contains("Can't reach"),
          ),
        ),
      );
    });

    test('a request that fails after the stream was cancelled is not an unhandled error', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final response = Completer<StreamedResponse>();
        final service = OllamaService(
          baseUrl: 'http://localhost:11434',
          clientFactory: () => MockClient.streaming((_, _) => response.future),
        );

        final subscription = service
            .chat(model: 'm', messages: _hi)
            .listen((_) {}, onError: (_) {});
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel(); // e.g. Close chat while waiting

        response.completeError(ClientException('connection closed'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty);
    });

    test('cancelling mid-stream stops reading and closes the client', () async {
      var closed = false;
      final body = StreamController<List<int>>();
      final service = OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: () => _ClosableClient(
          onClose: () => closed = true,
          response: StreamedResponse(body.stream, 200),
        ),
      );

      final tokens = <String>[];
      final subscription = service
          .chat(model: 'm', messages: _hi)
          .listen(tokens.add);
      body.add(
        utf8.encode(
          '${jsonEncode({
            'message': {'content': 'Hi'},
          })}\n',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await subscription.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(tokens, ['Hi']);
      expect(closed, isTrue);
      await body.close();
    });
  });
}
