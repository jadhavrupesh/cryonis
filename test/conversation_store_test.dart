import 'dart:convert';
import 'dart:io';

import 'package:cryonis/models/chat_message.dart';
import 'package:cryonis/services/conversation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A picture whose bytes are [text], as the picker would hand it over.
ChatImage _image(String text, {String name = 'photo.png'}) => ChatImage(
  name: name,
  mimeType: 'image/png',
  base64Data: base64Encode(utf8.encode(text)),
);

ChatMessage _user(String text, [List<ChatImage> images = const []]) =>
    ChatMessage(role: ChatRole.user, content: text, images: images);

void main() {
  late SharedPreferences prefs;
  late Directory directory;
  late ConversationStore store;

  List<String> files() => directory.existsSync()
      ? [for (final f in directory.listSync()) f.uri.pathSegments.last]
      : [];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    directory = Directory.systemTemp.createTempSync('chat_images_test_');
    store = ConversationStore(prefs, imagesDirectory: directory);
    addTearDown(() => directory.deleteSync(recursive: true));
  });

  test('keeps picture bytes out of the preference value', () async {
    final big = 'x' * 50000;
    store.save([_user('look', [_image(big)])], DateTime(2026, 11, 3));
    await store.flush();

    final saved = prefs.getString(ConversationStore.conversationKey)!;
    expect(saved, isNot(contains(base64Encode(utf8.encode(big)))));
    expect(saved.length, lessThan(500));
    expect(files(), hasLength(1));
    expect(files().single, matches(RegExp(r'^[0-9a-f]{64}\.img$')));
  });

  test('a picture survives a restart byte for byte', () async {
    final image = _image('pretend png bytes', name: 'planet.png');
    store.save([_user('what is this?', [image])], DateTime(2026, 11, 3, 9));
    await store.flush();

    final restored = ConversationStore(prefs, imagesDirectory: directory)
        .load();

    final message = restored.messages.single;
    expect(message.content, 'what is this?');
    expect(message.images.single.name, 'planet.png');
    expect(message.images.single.mimeType, 'image/png');
    expect(message.images.single.base64Data, image.base64Data);
    expect(restored.lastActivity, DateTime(2026, 11, 3, 9));
  });

  test('the same picture in two messages is stored once', () async {
    final image = _image('same');
    store.save([
      _user('first', [image]),
      _user('second', [_image('same')]),
    ], DateTime.now());
    await store.flush();

    expect(files(), hasLength(1));
  });

  test('pictures that are no longer in the conversation are deleted', () async {
    store.save([_user('a', [_image('one')])], DateTime.now());
    await store.flush();
    expect(files(), hasLength(1));

    store.save([_user('a', [_image('two')])], DateTime.now());
    await store.flush();
    expect(files(), hasLength(1));

    store.clear();
    await store.flush();
    expect(files(), isEmpty);
    expect(prefs.getString(ConversationStore.conversationKey), isNull);
    expect(prefs.getInt(ConversationStore.activityKey), isNull);
  });

  test('replacing a chat right after clearing it never loses the new one', () async {
    store.save([_user('old chat')], DateTime(2026, 11, 3, 8));
    store.clear(); // "new chat": reset() ...
    store.save([_user('new chat')], DateTime(2026, 11, 3, 9)); // ... then send()
    await store.flush();

    final restored = ConversationStore(prefs, imagesDirectory: directory)
        .load();
    expect(restored.messages.single.content, 'new chat');
    expect(restored.lastActivity, DateTime(2026, 11, 3, 9));
  });

  test('a burst of saves ends with the last one', () async {
    for (var i = 0; i < 25; i++) {
      store.save([_user('message $i')], DateTime(2026, 11, 3, 10, i));
    }
    await store.flush();

    final restored = ConversationStore(prefs, imagesDirectory: directory)
        .load();
    expect(restored.messages.single.content, 'message 24');
    expect(restored.lastActivity, DateTime(2026, 11, 3, 10, 24));
  });

  test('flush completes right away when nothing is queued', () async {
    await store.flush();
    store.save([_user('x')], DateTime.now());
    await store.flush();
    await store.flush();
  });

  test('an empty placeholder reply is not saved', () async {
    store.save([
      _user('question'),
      const ChatMessage(role: ChatRole.assistant, content: ''),
    ], DateTime.now());
    await store.flush();

    final restored = ConversationStore(prefs, imagesDirectory: directory)
        .load();
    expect(restored.messages.map((m) => m.content), ['question']);
  });

  test('a conversation saved with inline pictures is read and then moved to files', () async {
    final image = _image('legacy');
    SharedPreferences.setMockInitialValues({
      ConversationStore.conversationKey: jsonEncode([
        _user('older', [image]).toJson(),
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    store = ConversationStore(prefs, imagesDirectory: directory);

    final loaded = store.load();
    expect(loaded.messages.single.images.single.base64Data, image.base64Data);

    store.save(loaded.messages, DateTime.now());
    await store.flush();
    expect(
      prefs.getString(ConversationStore.conversationKey),
      isNot(contains(image.base64Data)),
    );
    expect(files(), hasLength(1));
    expect(store.load().messages.single.images.single.base64Data, image.base64Data);
  });

  test('without a pictures folder they stay inline, as before', () async {
    final inline = ConversationStore(prefs);
    final image = _image('inline');
    inline.save([_user('hi', [image])], DateTime.now());
    await inline.flush();

    expect(
      prefs.getString(ConversationStore.conversationKey),
      contains(image.base64Data),
    );
    expect(
      ConversationStore(prefs).load().messages.single.images.single.base64Data,
      image.base64Data,
    );
  });

  test('a missing picture file drops the picture, not the message', () async {
    store.save([_user('keep me', [_image('gone soon')])], DateTime.now());
    await store.flush();
    for (final f in directory.listSync()) {
      f.deleteSync();
    }

    final message = store.load().messages.single;
    expect(message.content, 'keep me');
    expect(message.images, isEmpty);
  });

  test('a saved file name that is a path is never read', () async {
    final outside = File('${directory.parent.path}/outside_secret.txt')
      ..writeAsStringSync('do not read me');
    addTearDown(() {
      if (outside.existsSync()) outside.deleteSync();
    });
    SharedPreferences.setMockInitialValues({
      ConversationStore.conversationKey: jsonEncode([
        {
          'role': 'user',
          'content': 'sneaky',
          'images': [
            {
              'name': 'x.png',
              'mimeType': 'image/png',
              'file': '../outside_secret.txt',
            },
          ],
        },
      ]),
    });
    prefs = await SharedPreferences.getInstance();

    final message = ConversationStore(prefs, imagesDirectory: directory)
        .load()
        .messages
        .single;
    expect(message.images, isEmpty);
  });

  test('if the folder cannot be used the picture is kept inline instead', () async {
    // A file where the pictures folder should be makes every write fail.
    final blocker = File('${directory.path}/blocked')..writeAsStringSync('x');
    final broken = ConversationStore(
      prefs,
      imagesDirectory: Directory(blocker.path),
    );
    final image = _image('must not be lost');

    broken.save([_user('hi', [image])], DateTime.now());
    await broken.flush();

    final restored = ConversationStore(prefs).load();
    expect(restored.messages.single.images.single.base64Data, image.base64Data);
  });

  test('corrupt saved data is skipped and removed', () async {
    SharedPreferences.setMockInitialValues({
      ConversationStore.conversationKey: jsonEncode([
        _user('valid').toJson(),
        {'role': 'unknown', 'content': 'bad'},
        12,
      ]),
    });
    prefs = await SharedPreferences.getInstance();
    expect(
      ConversationStore(prefs, imagesDirectory: directory)
          .load()
          .messages
          .single
          .content,
      'valid',
    );

    SharedPreferences.setMockInitialValues({
      ConversationStore.conversationKey: 'not json',
    });
    prefs = await SharedPreferences.getInstance();
    expect(ConversationStore(prefs).load().messages, isEmpty);
    expect(prefs.getString(ConversationStore.conversationKey), isNull);
  });
}
