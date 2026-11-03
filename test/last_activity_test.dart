import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/state/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ollama.dart';

ChatController _controller(SharedPreferences prefs) => ChatController(
  service: OllamaService(
    baseUrl: 'http://localhost:11434',
    clientFactory: fakeOllama.call,
  ),
  prefs: prefs,
);

void main() {
  test('the conversation remembers when it last changed, across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final chat = _controller(prefs);
    addTearDown(chat.dispose);

    expect(chat.lastActivity, isNull);

    final before = DateTime.now().subtract(const Duration(seconds: 1));
    chat.send('hello');
    expect(chat.lastActivity, isNotNull);
    expect(chat.lastActivity!.isAfter(before), isTrue);
    expect(prefs.getInt(ChatController.activityKey), isNotNull);

    final restored = _controller(prefs);
    addTearDown(restored.dispose);
    // Stored as whole milliseconds.
    expect(
      restored.lastActivity!.millisecondsSinceEpoch,
      chat.lastActivity!.millisecondsSinceEpoch,
    );
  });

  test('clearing the conversation clears its time', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final chat = _controller(prefs);
    addTearDown(chat.dispose);

    chat.send('hello');
    chat.reset();

    expect(chat.lastActivity, isNull);
    expect(prefs.getInt(ChatController.activityKey), isNull);
  });

  test('a saved conversation without a time still loads', () async {
    SharedPreferences.setMockInitialValues({
      ChatController.conversationKey:
          '[{"role":"user","content":"older chat"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final chat = _controller(prefs);
    addTearDown(chat.dispose);

    expect(chat.messages.single.content, 'older chat');
    expect(chat.lastActivity, isNull);
  });
}
