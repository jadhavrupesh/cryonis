// Shows, on a real device, which plain-http requests Dart's HTTP client can
// make:
//
//   flutter test integration_test/cleartext_policy_test.dart -d <device>
//
// It prints one `CLEARTEXT` line per request and asserts nothing.
//
// Why it exists: on 3 November 2026 this showed that Android's network
// security config (android/app/src/main/res/xml/network_security_config.xml,
// which only allows localhost, 127.0.0.1 and 10.0.2.2) does NOT restrict this
// client: a plain-http request to a public host still went out and came back
// with a redirect. The rule that protects Ollama traffic is therefore enforced
// in Dart, in OllamaService (see serverSecurity in lib/app_config.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

Future<String> _try(Uri url) async {
  final client = http.Client();
  try {
    // Do not follow redirects: a 301 to https already proves the plain-http
    // request left the device.
    final request = http.Request('GET', url)..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    return 'allowed (HTTP ${response.statusCode})';
  } on SocketException catch (error) {
    return 'socket error: ${error.message}';
  } on Object catch (error) {
    return 'blocked or failed: $error';
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('which plain-http hosts can the app reach', (tester) async {
    await tester.runAsync(() async {
      for (final url in [
        'http://ollama.com/', // public host that redirects plain http to https
        'https://ollama.com/', // control: https must always work
        'http://127.0.0.1:9/', // this device: allowed by policy, nothing listens
        'http://10.0.2.2:9/', // emulator host: allowed by policy, unreachable here
      ]) {
        // ignore: avoid_print
        print('CLEARTEXT $url -> ${await _try(Uri.parse(url))}');
      }
    });
  });
}
