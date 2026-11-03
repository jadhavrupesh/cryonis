import 'package:cryonis/widgets/code_block.dart';
import 'package:cryonis/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _answer = '''
# Plan

Some **bold** text, *italic* text and `inline_code`.

- first point
- second point

1. step one
2. step two

> A quoted remark.

| Model | Free |
|-------|------|
| gpt-oss:120b | yes |

```dart
void main() => print('hi');
```
''';

Future<void> _pump(WidgetTester tester, String data) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MarkdownView(data),
        ),
      ),
    ),
  );
}

Finder _rich(String text) => find.text(text, findRichText: true);

void main() {
  testWidgets('renders headings, lists, quote, table and a code block', (
    tester,
  ) async {
    await _pump(tester, _answer);

    expect(_rich('Plan'), findsOneWidget);
    expect(find.textContaining('bold', findRichText: true), findsOneWidget);
    expect(_rich('first point'), findsOneWidget);
    expect(_rich('1.'), findsOneWidget, reason: 'numbered list marker');
    expect(_rich('A quoted remark.'), findsOneWidget);

    expect(find.byType(Table), findsOneWidget);
    expect(_rich('gpt-oss:120b'), findsOneWidget);

    // The fenced block becomes a header bar (language + copy) and the code.
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(
      find.textContaining('void main', findRichText: true),
      findsOneWidget,
    );

    // Raw Markdown syntax must not leak into the output.
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.textContaining('```', findRichText: true), findsNothing);
    expect(find.textContaining('# Plan', findRichText: true), findsNothing);
  });

  testWidgets('the code block Copy button copies only the code', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(tester, _answer);
    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, "void main() => print('hi');");
    expect(find.text('Copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // the tick resets
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a code fence that is still streaming renders as a code block', (
    tester,
  ) async {
    await _pump(tester, 'Here you go:\n\n```python\nprint(1');

    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.text('python'), findsOneWidget);
    expect(find.textContaining('print', findRichText: true), findsOneWidget);
  });

  testWidgets('an unknown or missing code language still renders', (
    tester,
  ) async {
    await _pump(tester, '```madeup-lang\nfoo bar\n```\n\n```\nplain\n```');

    expect(find.byType(CodeBlock), findsNWidgets(2));
    expect(find.text('madeup-lang'), findsOneWidget);
    expect(find.text('code'), findsOneWidget);
  });
}
