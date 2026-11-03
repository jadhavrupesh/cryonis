import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/chat_message.dart';

const maxChatImages = 4;
const maxChatImageBytes = 5 * 1024 * 1024;

class ImageAttachmentException implements Exception {
  const ImageAttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<List<ChatImage>> pickImageAttachments({required int remaining}) async {
  if (remaining <= 0) {
    throw const ImageAttachmentException('You can attach up to 4 images.');
  }
  const types = XTypeGroup(
    label: 'images',
    extensions: ['png', 'jpg', 'jpeg', 'webp'],
    mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
  );
  final files = await openFiles(acceptedTypeGroups: const [types]);
  if (files.length > remaining) {
    throw ImageAttachmentException(
      'Choose no more than $remaining additional image${remaining == 1 ? '' : 's'}.',
    );
  }
  return [
    for (final file in files)
      chatImageFromBytes(name: file.name, bytes: await file.readAsBytes()),
  ];
}

ChatImage chatImageFromBytes({required String name, required Uint8List bytes}) {
  if (bytes.length > maxChatImageBytes) {
    throw const ImageAttachmentException('Each image must be 5 MB or smaller.');
  }
  final extension = name.split('.').last.toLowerCase();
  final mimeType = switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => throw const ImageAttachmentException('Use a PNG, JPG, or WebP image.'),
  };
  return ChatImage(
    name: name,
    mimeType: mimeType,
    base64Data: base64Encode(bytes),
  );
}
