import 'package:cryonis/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat message JSON round-trips images and error state', () {
    const message = ChatMessage(
      role: ChatRole.user,
      content: 'look',
      isError: true,
      images: [
        ChatImage(name: 'ice.webp', mimeType: 'image/webp', base64Data: 'aWNl'),
      ],
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.role, ChatRole.user);
    expect(restored.content, 'look');
    expect(restored.isError, isTrue);
    expect(restored.images.single.name, 'ice.webp');
    expect(restored.images.single.base64Data, 'aWNl');
  });

  test('legacy JSON without optional fields remains readable', () {
    final message = ChatMessage.fromJson({
      'role': 'assistant',
      'content': 'hello',
    });

    expect(message.isError, isFalse);
    expect(message.images, isEmpty);
  });

  test('malformed JSON throws a format exception', () {
    expect(
      () => ChatMessage.fromJson({'role': 'system', 'content': 'bad'}),
      throwsFormatException,
    );
  });
}
