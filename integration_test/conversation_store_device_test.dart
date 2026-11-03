// Checks on a real device or desktop app that attached pictures are saved as
// files in the app's support folder and read back after a restart. It touches
// only a folder named chat_images_integration_test, which it removes.
//
//   flutter test integration_test/conversation_store_device_test.dart -d <device>
import 'dart:convert';
import 'dart:io';

import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/services/conversation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pictures are saved as files in the support folder', (
    tester,
  ) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/chat_images_integration_test');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      // A 3 MB "picture": large enough to show it no longer goes through prefs.
      final bytes = List<int>.generate(3 * 1024 * 1024, (i) => i % 251);
      final image = ChatImage(
        name: 'big.jpg',
        mimeType: 'image/jpeg',
        base64Data: base64Encode(bytes),
      );

      final store = ConversationStore(prefs, imagesDirectory: directory);
      store.save([
        ChatMessage(
          role: ChatRole.user,
          content: 'device check',
          images: [image],
        ),
      ], DateTime.now());
      await store.flush();

      final saved = prefs.getString(ConversationStore.conversationKey)!;
      expect(saved.length, lessThan(1000));
      final files = directory.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(files.single.lengthSync(), bytes.length);

      final restored = ConversationStore(prefs, imagesDirectory: directory)
          .load();
      expect(restored.messages.single.images.single.base64Data, image.base64Data);
      // ignore: avoid_print
      print('DEVICE-CHECK saved ${bytes.length} bytes as ${files.single.path}');
    });
  });
}
