import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';

/// An in-memory stand-in for the Ollama server.
///
/// [captured] receives the decoded JSON body of every `/api/chat` request and
/// [capturedHeaders] the headers of every request.
MockClient fakeOllama({
  List<String> models = const ['llama3.2:latest', 'qwen2.5:7b'],
  List<String> tokens = const ['Hello', ' world'],
  int chatStatus = 200,
  String? chatError,
  int tagsStatus = 200,
  List<Map<String, dynamic>>? captured,
  List<Map<String, String>>? capturedHeaders,
}) {
  return MockClient.streaming((request, bodyStream) async {
    capturedHeaders?.add(request.headers);

    if (request.url.path == '/api/tags') {
      if (tagsStatus != 200) {
        final body = jsonEncode({'error': 'unauthorized'});
        return StreamedResponse(Stream.value(utf8.encode(body)), tagsStatus);
      }
      final body = jsonEncode({
        'models': [
          for (final m in models) {'name': m},
        ],
      });
      return StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }

    captured?.add(
      jsonDecode(await bodyStream.bytesToString()) as Map<String, dynamic>,
    );

    if (chatStatus != 200) {
      final body = jsonEncode({'error': chatError ?? 'boom'});
      return StreamedResponse(Stream.value(utf8.encode(body)), chatStatus);
    }

    final lines = [
      for (final t in tokens)
        jsonEncode({
          'message': {'role': 'assistant', 'content': t},
          'done': false,
        }),
      jsonEncode({
        'message': {'role': 'assistant', 'content': ''},
        'done': true,
      }),
    ];
    return StreamedResponse(
      Stream.fromIterable([for (final l in lines) utf8.encode('$l\n')]),
      200,
    );
  });
}
