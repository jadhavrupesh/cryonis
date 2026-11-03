import 'dart:convert';
import 'dart:io';

import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/services/api_key_store.dart';
import 'package:cryonis/services/conversation_store.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ollama.dart';

Future<ChatController> _controller(
  MockClient Function() client, {
  Map<String, Object> prefs = const {},
  ApiKeyStore? apiKeyStore,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  return ChatController(
    service: OllamaService(
      baseUrl: 'http://localhost:11434',
      clientFactory: client,
    ),
    prefs: store,
    apiKeyStore: apiKeyStore,
  );
}

Future<void> _untilIdle(ChatController chat) async {
  while (chat.isStreaming) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('refreshModels selects the first model when none was saved', () async {
    final chat = await _controller(fakeOllama.call);
    await chat.refreshModels();

    expect(chat.connection, Connection.online);
    expect(chat.models, ['llama3.2:latest', 'qwen2.5:7b']);
    expect(chat.selectedModel, 'llama3.2:latest');
  });

  test(
    'refreshModels prefers a known good model over alphabetical order',
    () async {
      final chat = await _controller(
        () => fakeOllama(models: const ['beam', 'gpt-oss:20b', 'kimi-k3']),
      );
      await chat.refreshModels();
      expect(chat.selectedModel, 'gpt-oss:20b');
    },
  );

  test(
    'Ollama Cloud without an API key asks for one and makes no request',
    () async {
      final requests = <Map<String, String>>[];
      final chat = await _controller(
        () => fakeOllama(capturedHeaders: requests),
      );

      await chat.setServer(url: 'https://ollama.com');

      expect(chat.needsApiKey, isTrue);
      expect(chat.connection, Connection.offline);
      expect(chat.connectionError, contains('API key'));
      expect(requests, isEmpty);

      chat.send('hi');
      expect(chat.messages.last.isError, isTrue);
      expect(chat.messages.last.content, contains('API key'));
    },
  );

  test('Ollama Cloud with an API key connects and lists models', () async {
    final headers = <Map<String, String>>[];
    final chat = await _controller(() => fakeOllama(capturedHeaders: headers));

    await chat.setServer(url: 'https://ollama.com', apiKey: 'secret');

    expect(chat.needsApiKey, isFalse);
    expect(chat.connection, Connection.online);
    expect(headers.single['Authorization'], 'Bearer secret');
  });

  test('with the API key only free Ollama Cloud models are offered', () async {
    final chat = await _controller(
      () => fakeOllama(
        models: const [
          'deepseek-v4-pro:0813', // paid (402)
          'gemma4:31b', // free
          'kimi-k3', // paid
          'gpt-oss:120b', // free
          'clef:27b', // not a chat model
        ],
      ),
    );

    await chat.setServer(url: 'https://ollama.com', apiKey: 'secret');

    expect(chat.models, ['gemma4:31b', 'gpt-oss:120b']);
    expect(chat.selectedModel, 'gpt-oss:120b');
  });

  test('a local server shows every installed model', () async {
    final chat = await _controller(
      () => fakeOllama(models: const ['kimi-k3', 'llama3.2:latest']),
    );

    await chat.setServer(url: 'http://localhost:11434');

    expect(chat.models, ['kimi-k3', 'llama3.2:latest']);
  });

  test('refreshModels keeps a saved model that is still installed', () async {
    final chat = await _controller(
      fakeOllama.call,
      prefs: {'ollama_model': 'qwen2.5:7b'},
    );
    await chat.refreshModels();
    expect(chat.selectedModel, 'qwen2.5:7b');
  });

  test('send streams the reply into an assistant message', () async {
    final chat = await _controller(fakeOllama.call);
    await chat.refreshModels();

    chat.send('  hi  ');
    expect(chat.isStreaming, isTrue);
    expect(chat.isWorking, isTrue);
    await _untilIdle(chat);

    expect(chat.messages.map((m) => (m.role, m.content)), [
      (ChatRole.user, 'hi'),
      (ChatRole.assistant, 'Hello world'),
    ]);
  });

  test('later turns send the whole conversation as history', () async {
    final captured = <Map<String, dynamic>>[];
    final chat = await _controller(() => fakeOllama(captured: captured));
    await chat.refreshModels();

    chat.send('one');
    await _untilIdle(chat);
    chat.send('two');
    await _untilIdle(chat);

    final roles = [
      for (final m in captured.last['messages'] as List) (m as Map)['role'],
    ];
    expect(roles, ['system', 'user', 'assistant', 'user']);
  });

  test(
    'regenerate replaces the last answer, keeping the conversation',
    () async {
      var reply = const ['First'];
      final captured = <Map<String, dynamic>>[];
      final chat = await _controller(
        () => fakeOllama(tokens: reply, captured: captured),
      );
      await chat.refreshModels();

      chat.send('hi');
      await _untilIdle(chat);
      expect(chat.messages.last.content, 'First');

      reply = const ['Second'];
      chat.regenerate();
      await _untilIdle(chat);

      expect(chat.messages.map((m) => m.content), ['hi', 'Second']);
      // The first answer is not part of the history sent for the second try.
      final sent = captured.last['messages'] as List;
      expect(sent.map((m) => (m as Map)['role']), ['system', 'user']);
    },
  );

  test(
    'regenerate does nothing while streaming or without an answer',
    () async {
      final chat = await _controller(fakeOllama.call);
      await chat.refreshModels();

      chat.regenerate(); // empty conversation
      expect(chat.messages, isEmpty);

      chat.send('hi'); // now streaming
      chat.regenerate();
      await _untilIdle(chat);
      expect(chat.messages.map((m) => m.content), ['hi', 'Hello world']);
    },
  );

  test('a failed reply becomes a retryable error message', () async {
    var failing = true;
    final chat = await _controller(
      () => failing
          ? fakeOllama(chatStatus: 500, chatError: 'boom')
          : fakeOllama(),
    );
    await chat.refreshModels();

    chat.send('hi');
    await _untilIdle(chat);
    expect(chat.messages.last.isError, isTrue);
    expect(chat.messages.last.content, 'boom');

    failing = false;
    chat.retry();
    await _untilIdle(chat);
    expect(chat.messages.map((m) => m.content), ['hi', 'Hello world']);
  });

  test(
    'setServer saves the address and API key, and clearing the key removes it',
    () async {
      final secrets = MemorySecretStore();
      final chat = await _controller(
        fakeOllama.call,
        apiKeyStore: ApiKeyStore(secrets),
      );

      await chat.setServer(url: 'ollama.com/', apiKey: ' key ');
      expect(chat.baseUrl, 'http://ollama.com');
      expect(chat.apiKey, 'key');
      expect(chat.connection, Connection.online);

      final prefs = await SharedPreferences.getInstance();
      expect(ChatController.savedBaseUrl(prefs), 'http://ollama.com');
      expect(secrets.values[ApiKeyStore.key], 'key');
      expect(prefs.getString(ApiKeyStore.key), isNull);

      await chat.setServer(url: 'http://localhost:11434');
      expect(chat.apiKey, isEmpty);
      expect(secrets.values[ApiKeyStore.key], isNull);
    },
  );

  test(
    'live voice is configured only while a LiveKit sandbox ID is set',
    () async {
      final chat = await _controller(fakeOllama.call);
      expect(chat.voiceAgentConfigured, isFalse);

      await chat.setLivekitSandboxId('  sandbox-123  ');
      expect(chat.livekitSandboxId, 'sandbox-123');
      expect(chat.voiceAgentConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('livekit_sandbox_id'), 'sandbox-123');

      await chat.setLivekitSandboxId('');
      expect(chat.voiceAgentConfigured, isFalse);
      expect(prefs.getString('livekit_sandbox_id'), isNull);
    },
  );

  test(
    'a production voice token endpoint is validated and persisted',
    () async {
      final chat = await _controller(fakeOllama.call);

      await chat.setLivekitTokenEndpoint(
        '  https://api.example.com/livekit-token  ',
      );
      expect(
        chat.livekitTokenEndpoint,
        'https://api.example.com/livekit-token',
      );
      expect(chat.usesProductionVoiceEndpoint, isTrue);
      expect(chat.voiceAgentConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('livekit_token_endpoint'),
        'https://api.example.com/livekit-token',
      );

      expect(
        () => chat.setLivekitTokenEndpoint('http://api.example.com/token'),
        throwsArgumentError,
      );
      expect(
        () =>
            chat.setLivekitTokenEndpoint('https://user:pass@example.com/token'),
        throwsArgumentError,
      );

      await chat.setLivekitTokenEndpoint('');
      expect(chat.voiceAgentConfigured, isFalse);
      expect(prefs.getString('livekit_token_endpoint'), isNull);
    },
  );

  test(
    'the sandbox ID comes from the saved setting, else the built-in one',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ChatController make() => ChatController(
        service: OllamaService(
          baseUrl: 'http://localhost:11434',
          clientFactory: fakeOllama.call,
        ),
        prefs: prefs,
        livekitSandboxId: 'built-in',
      );

      expect(make().livekitSandboxId, 'built-in');

      await prefs.setString('livekit_sandbox_id', 'saved');
      expect(make().livekitSandboxId, 'saved');
    },
  );

  test(
    'turns from a voice call join the chat, and the model sees them as history',
    () async {
      final captured = <Map<String, dynamic>>[];
      final chat = await _controller(() => fakeOllama(captured: captured));
      await chat.refreshModels();

      chat.addConversation(const [
        ChatMessage(role: ChatRole.user, content: 'hi there'),
        ChatMessage(role: ChatRole.assistant, content: 'Hello!'),
        ChatMessage(
          role: ChatRole.user,
          content: '   ',
        ), // empty turns are skipped
      ]);
      expect(chat.messages.map((m) => m.content), ['hi there', 'Hello!']);

      chat.send('and then?');
      await _untilIdle(chat);

      final roles = [
        for (final m in captured.last['messages'] as List) (m as Map)['role'],
      ];
      expect(roles, ['system', 'user', 'assistant', 'user']);
    },
  );

  test('sending with no model installed explains how to get one', () async {
    final chat = await _controller(() => fakeOllama(models: const []));
    await chat.refreshModels();

    chat.send('hi');
    expect(chat.isStreaming, isFalse);
    expect(chat.messages.last.isError, isTrue);
    expect(chat.messages.last.content, contains('ollama pull'));
  });

  test('stop keeps the partial reply, reset clears everything', () async {
    final chat = await _controller(fakeOllama.call);
    await chat.refreshModels();

    chat.send('hi');
    chat.stop();
    expect(chat.isStreaming, isFalse);
    expect(chat.messages.single.role, ChatRole.user);

    chat.reset();
    expect(chat.messages, isEmpty);
  });

  test(
    'completed conversations are restored after recreating the controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ChatController(
        service: OllamaService(
          baseUrl: 'http://localhost:11434',
          clientFactory: fakeOllama.call,
        ),
        prefs: prefs,
      );
      await first.refreshModels();
      first.send('remember me');
      await _untilIdle(first);

      final restored = ChatController(
        service: OllamaService(
          baseUrl: 'http://localhost:11434',
          clientFactory: fakeOllama.call,
        ),
        prefs: prefs,
      );
      expect(restored.messages.map((message) => message.content), [
        'remember me',
        'Hello world',
      ]);
    },
  );

  test(
    'restore skips corrupt records and reset removes persisted history',
    () async {
      final valid = const ChatMessage(
        role: ChatRole.user,
        content: 'valid',
      ).toJson();
      final chat = await _controller(
        fakeOllama.call,
        prefs: {
          ChatController.conversationKey: jsonEncode([
            valid,
            {'role': 'unknown', 'content': 'bad'},
            12,
          ]),
        },
      );

      expect(chat.messages.single.content, 'valid');
      chat.reset();
      await chat.flush();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ChatController.conversationKey), isNull);
    },
  );

  test('a new chat started right after clearing the old one is what is saved', () async {
    final chat = await _controller(fakeOllama.call);
    await chat.refreshModels();
    chat.send('old question');
    await _untilIdle(chat);

    // The home screen does exactly this when you type into a fresh prompt.
    chat.reset();
    chat.send('new question');
    await _untilIdle(chat);
    await chat.flush();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ChatController.conversationKey)!;
    expect(saved, contains('new question'));
    expect(saved, isNot(contains('old question')));
  });

  test('with a pictures folder an image prompt is saved as a file, not in preferences', () async {
    final directory = Directory.systemTemp.createTempSync('controller_images_');
    addTearDown(() => directory.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ChatController build() => ChatController(
      service: OllamaService(
        baseUrl: 'http://localhost:11434',
        clientFactory: fakeOllama.call,
      ),
      prefs: prefs,
      conversationStore: ConversationStore(prefs, imagesDirectory: directory),
    );
    final chat = build();
    await chat.refreshModels();
    const image = ChatImage(
      name: 'planet.png',
      mimeType: 'image/png',
      base64Data: 'cG5n',
    );

    chat.send('What is this?', images: [image]);
    await _untilIdle(chat);
    await chat.flush();

    expect(prefs.getString(ChatController.conversationKey), isNot(contains('cG5n')));
    expect(directory.listSync(), hasLength(1));
    // After a restart the picture is back, ready to be sent again.
    expect(build().messages.first.images.single.base64Data, 'cG5n');
  });

  test('image prompts are sent to Ollama and persisted', () async {
    final captured = <Map<String, dynamic>>[];
    final image = const ChatImage(
      name: 'planet.png',
      mimeType: 'image/png',
      base64Data: 'cG5n',
    );
    final chat = await _controller(() => fakeOllama(captured: captured));
    await chat.refreshModels();

    chat.send('What is this?', images: [image]);
    await _untilIdle(chat);

    final messages = captured.single['messages'] as List<dynamic>;
    expect((messages[1] as Map<String, dynamic>)['images'], ['cG5n']);
    await chat.flush();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ChatController.conversationKey),
      contains('planet.png'),
    );
  });
}
