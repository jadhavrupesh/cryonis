import 'package:cryonis/app_config.dart';
import 'package:cryonis/services/ollama_service.dart';
import 'package:cryonis/widgets/sheets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_ollama.dart';

void main() {
  group('serverSecurity', () {
    const cases = <String, ServerSecurity>{
      'https://ollama.com': ServerSecurity.encrypted,
      'https://example.org:8443/x': ServerSecurity.encrypted,
      'HTTPS://Ollama.com': ServerSecurity.encrypted,
      // This device and the emulator's host machine.
      'http://localhost:11434': ServerSecurity.thisDevice,
      'http://127.0.0.1:11434': ServerSecurity.thisDevice,
      'http://127.1.2.3': ServerSecurity.thisDevice,
      'http://10.0.2.2:11434': ServerSecurity.thisDevice,
      'http://[::1]:11434': ServerSecurity.thisDevice,
      // The local network.
      'http://192.168.1.20:11434': ServerSecurity.localNetwork,
      'http://10.1.2.3:11434': ServerSecurity.localNetwork,
      'http://172.16.0.5': ServerSecurity.localNetwork,
      'http://172.31.255.255': ServerSecurity.localNetwork,
      'http://169.254.10.10': ServerSecurity.localNetwork,
      'http://mac-mini.local:11434': ServerSecurity.localNetwork,
      'http://mac-mini:11434': ServerSecurity.localNetwork,
      'http://[fd12:3456::1]:11434': ServerSecurity.localNetwork,
      'http://[fe80::1]:11434': ServerSecurity.localNetwork,
      // The internet.
      'http://ollama.com': ServerSecurity.exposed,
      'http://example.org:11434': ServerSecurity.exposed,
      'http://8.8.8.8': ServerSecurity.exposed,
      'http://172.15.0.1': ServerSecurity.exposed,
      'http://172.32.0.1': ServerSecurity.exposed,
      'http://192.169.0.1': ServerSecurity.exposed,
      'http://[2606:4700::1111]': ServerSecurity.exposed,
      // Not an address.
      '': ServerSecurity.invalid,
      'ftp://example.org': ServerSecurity.invalid,
      'http://': ServerSecurity.invalid,
    };

    cases.forEach((url, expected) {
      test('"$url" is $expected', () {
        expect(serverSecurity(url), expected);
      });
    });

    test(
      'an address typed without a scheme gets http only where that is safe',
      () {
        String fixed(String input) => OllamaService.normalizeBaseUrl(input);

        expect(fixed('ollama.com'), 'https://ollama.com');
        expect(fixed('example.org:11434/'), 'https://example.org:11434');
        expect(fixed('8.8.8.8'), 'https://8.8.8.8');
        expect(fixed('localhost:11434'), 'http://localhost:11434');
        expect(fixed('192.168.0.9:11434'), 'http://192.168.0.9:11434');
        expect(fixed('mac-mini.local'), 'http://mac-mini.local');
        // What was typed with a scheme is kept, and then judged by the rules.
        expect(fixed('http://example.org'), 'http://example.org');
        expect(
          serverSecurity(fixed('http://example.org')),
          ServerSecurity.exposed,
        );
      },
    );
  });

  group('OllamaService refuses plain http to the internet', () {
    OllamaService service(String url, {List<Map<String, String>>? requested}) {
      return OllamaService(
        baseUrl: url,
        clientFactory: () => fakeOllama(capturedHeaders: requested),
      );
    }

    test('listing models never sends the request', () async {
      final requested = <Map<String, String>>[];
      final ollama = service('http://example.org:11434', requested: requested);

      await expectLater(
        ollama.listModels(),
        throwsA(
          isA<OllamaException>().having(
            (e) => e.message,
            'message',
            contains('Plain http to a server on the internet is blocked'),
          ),
        ),
      );
      expect(requested, isEmpty);
    });

    test('chatting never sends the request either', () async {
      final requested = <Map<String, String>>[];
      final ollama = service('http://example.org:11434', requested: requested);

      await expectLater(
        ollama.chat(model: 'm', messages: const []),
        emitsError(isA<OllamaException>()),
      );
      expect(requested, isEmpty);
    });

    for (final url in [
      'https://ollama.com',
      'http://localhost:11434',
      'http://10.0.2.2:11434',
      'http://192.168.1.20:11434',
    ]) {
      test('$url still works', () async {
        final requested = <Map<String, String>>[];
        final ollama = service(url, requested: requested);

        expect(await ollama.listModels(), isNotEmpty);
        expect(requested, isNotEmpty);
      });
    }
  });

  group('the settings notice', () {
    test('warns on the local network without blocking', () {
      final notice = plainHttpNotice(ServerSecurity.localNetwork)!;
      expect(notice.blocked, isFalse);
      expect(notice.text, contains('not encrypted'));
    });

    test('says an internet address is blocked', () {
      final notice = plainHttpNotice(ServerSecurity.exposed)!;
      expect(notice.blocked, isTrue);
      expect(notice.text, contains('blocked'));
    });

    test('says nothing for https, this device or an invalid address', () {
      for (final security in [
        ServerSecurity.encrypted,
        ServerSecurity.thisDevice,
        ServerSecurity.invalid,
      ]) {
        expect(plainHttpNotice(security), isNull);
      }
    });
  });
}
