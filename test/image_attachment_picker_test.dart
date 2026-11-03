import 'dart:typed_data';

import 'package:cryonis/services/image_attachment_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes a supported image for Ollama', () {
    final image = chatImageFromBytes(
      name: 'sample.PNG',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(image.mimeType, 'image/png');
    expect(image.base64Data, 'AQID');
  });

  test('rejects unsupported file extensions', () {
    expect(
      () => chatImageFromBytes(
        name: 'sample.gif',
        bytes: Uint8List.fromList([1]),
      ),
      throwsA(isA<ImageAttachmentException>()),
    );
  });

  test('rejects images larger than 5 MB', () {
    expect(
      () => chatImageFromBytes(
        name: 'large.jpg',
        bytes: Uint8List(maxChatImageBytes + 1),
      ),
      throwsA(isA<ImageAttachmentException>()),
    );
  });
}
