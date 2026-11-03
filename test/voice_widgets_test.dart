import 'dart:math' as math;

import 'package:cryonis/widgets/dot_ring.dart';
import 'package:cryonis/widgets/glow_backdrop.dart';
import 'package:cryonis/widgets/voice_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: Colors.black, body: Center(child: child)),
);

Future<void> _run(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The colour of the word at [index] in the RichText showing [plain].
Color? _wordColor(WidgetTester tester, String plain, int index) {
  final richText = tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == plain,
    ),
  );
  // Text.rich wraps our span in its own root span.
  final ours = (richText.text as TextSpan).children!.single as TextSpan;
  return (ours.children![index] as TextSpan).style?.color;
}

void main() {
  group('DotRing', () {
    testWidgets('paints every mood, quiet and loud, without errors', (
      tester,
    ) async {
      for (final mood in DotRingMood.values) {
        for (final level in [0.0, 0.5, 1.0]) {
          await tester.pumpWidget(_host(DotRing(mood: mood, level: level)));
          await _run(tester, 4);
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps going when motion is reduced and stops when removed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _host(const DotRing(mood: DotRingMood.speaking, level: 1)),
        ),
      );
      await _run(tester, 6);

      // A ticker that outlived the widget would fail this test.
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the motion of each phase', () {
    test('the comet arc is brightest at its head and trails behind it', () {
      const head = 1.0;
      expect(sweepFactor(head, head), closeTo(1, 1e-9));
      // Behind the head (the way it came) decays slower than ahead of it.
      final behind = sweepFactor(head - 0.5, head);
      final ahead = sweepFactor(head + 0.5, head);
      expect(behind, greaterThan(ahead));
      // Far from the head only a faint ghost of the ring is left.
      expect(sweepFactor(head + math.pi, head), inInclusiveRange(0.4, 0.5));
      for (var a = -7.0; a < 7; a += 0.3) {
        expect(sweepFactor(a, head), inInclusiveRange(0.4, 1.0));
      }
    });

    test('the arc is periodic in the angle', () {
      expect(
        sweepFactor(0.7 + 2 * math.pi, 0.2),
        closeTo(sweepFactor(0.7, 0.2), 1e-9),
      );
    });

    // The ripple is a travelling wave: the brightness found at one radius
    // reappears further out (or in) one moment later, at 4.6 / 0.085 dp/s.
    const speed = 4.6 / 0.085;

    test('outward ripples carry the same brightness away from the centre', () {
      for (var r = 60.0; r < 140; r += 7) {
        for (var c = 0.0; c < 2; c += 0.3) {
          const dt = 0.1;
          expect(
            rippleFactor(r + speed * dt, c + dt, outward: true),
            closeTo(rippleFactor(r, c, outward: true), 1e-9),
          );
        }
      }
    });

    test('inward ripples carry it towards the centre', () {
      for (var r = 60.0; r < 140; r += 7) {
        for (var c = 0.0; c < 2; c += 0.3) {
          const dt = 0.1;
          expect(
            rippleFactor(r - speed * dt, c + dt, outward: false),
            closeTo(rippleFactor(r, c, outward: false), 1e-9),
          );
        }
      }
    });

    test('and they do not mirror each other', () {
      expect(
        rippleFactor(100, 0.5, outward: true),
        isNot(closeTo(rippleFactor(100, 0.5, outward: false), 1e-3)),
      );
    });

    test('a ripple always keeps the ring at least 24 % lit', () {
      for (var r = 40.0; r < 156; r += 1) {
        for (var c = 0.0; c < 3; c += 0.1) {
          expect(rippleFactor(r, c, outward: true), inInclusiveRange(0.24, 1.0));
        }
      }
    });

    testWidgets('every mood still paints while words are arriving', (
      tester,
    ) async {
      for (final mood in DotRingMood.values) {
        await tester.pumpWidget(
          _host(DotRing(mood: mood, level: 0.6, converging: true)),
        );
        await _run(tester, 6);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing mood and converging glides without errors', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const DotRing(mood: DotRingMood.listening)));
      await _run(tester, 5);
      await tester.pumpWidget(
        _host(const DotRing(mood: DotRingMood.listening, converging: true)),
      );
      await _run(tester, 10);
      await tester.pumpWidget(_host(const DotRing(mood: DotRingMood.thinking)));
      await _run(tester, 10);
      await tester.pumpWidget(
        _host(const DotRing(mood: DotRingMood.speaking, level: 0.9)),
      );
      await _run(tester, 10);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('GlowBackdrop glides between colours without errors', (
    tester,
  ) async {
    Widget glow(Color color, double strength, double bias) => _host(
      SizedBox(
        width: 300,
        height: 600,
        child: GlowBackdrop(color: color, intensity: strength, leftBias: bias),
      ),
    );

    await tester.pumpWidget(glow(const Color(0xFF5D3500), 1, 0));
    await _run(tester, 4);
    await tester.pumpWidget(glow(const Color(0xFF7A5800), 0.5, 0.8));
    await _run(tester, 24);
    await tester.pumpWidget(glow(const Color(0xFF5D3500), 0, 0));
    await _run(tester, 24);

    expect(tester.takeException(), isNull);
  });

  group('WordRevealText', () {
    const style = TextStyle(color: Colors.white, fontSize: 18);

    Widget reveal(String text) => _host(
      SizedBox(
        width: 300,
        child: WordRevealText(text: text, style: style),
      ),
    );

    testWidgets('shows text that is already there in full white', (
      tester,
    ) async {
      await tester.pumpWidget(reveal('one two'));

      expect(_wordColor(tester, 'one two', 0), Colors.white);
      expect(_wordColor(tester, 'one two', 1), Colors.white);
    });

    testWidgets('a new word arrives grey and turns white', (tester) async {
      await tester.pumpWidget(reveal('one two'));
      await tester.pumpWidget(reveal('one two three'));
      await tester.pump(const Duration(milliseconds: 16));

      expect(_wordColor(tester, 'one two three', 0), Colors.white);
      expect(_wordColor(tester, 'one two three', 1), Colors.white);
      final arriving = _wordColor(tester, 'one two three', 2)!;
      expect(arriving, isNot(Colors.white));
      expect(arriving.r, lessThan(0.6));

      await _run(tester, 12); // well past the 350 ms reveal
      expect(_wordColor(tester, 'one two three', 2), Colors.white);
    });

    testWidgets('a word after an earlier reveal has finished is still grey first', (
      tester,
    ) async {
      await tester.pumpWidget(reveal('one'));
      await tester.pumpWidget(reveal('one two'));
      await _run(tester, 12); // the first reveal completes and the ticker stops

      await tester.pumpWidget(reveal('one two three'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final arriving = _wordColor(tester, 'one two three', 2)!;
      expect(arriving.r, lessThan(0.7), reason: 'it starts dim, not already white');
      await _run(tester, 12);
      expect(_wordColor(tester, 'one two three', 2), Colors.white);
    });

    testWidgets('words that arrive together are staggered', (tester) async {
      await tester.pumpWidget(reveal('one'));
      await tester.pumpWidget(reveal('one two three four'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 120));

      final second = _wordColor(tester, 'one two three four', 1)!;
      final fourth = _wordColor(tester, 'one two three four', 3)!;
      expect(second.r, greaterThan(fourth.r));
    });

    testWidgets('a replaced text restarts only the words that changed', (
      tester,
    ) async {
      await tester.pumpWidget(reveal('hello there'));
      await tester.pumpWidget(reveal('hello world'));
      await tester.pump(const Duration(milliseconds: 16));

      expect(_wordColor(tester, 'hello world', 0), Colors.white);
      expect(_wordColor(tester, 'hello world', 1), isNot(Colors.white));
      await _run(tester, 12);
      expect(tester.takeException(), isNull);
    });
  });

  group('ListeningCaption', () {
    testWidgets('the dots count up one to three', (tester) async {
      await tester.pumpWidget(_host(const ListeningCaption(text: "I'm Listening")));

      final first = tester.widget<Text>(find.byType(Text).last);
      final spans = (first.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans[0].style!.color, isNot(Colors.transparent));
      expect(spans[1].style!.color, Colors.transparent);

      await tester.pump(const Duration(milliseconds: 1200)); // 80 % of a cycle
      final later = tester.widget<Text>(find.byType(Text).last);
      final lit = (later.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(lit.every((span) => span.style!.color != Colors.transparent), isTrue);
    });

    testWidgets('without dots it is just the words', (tester) async {
      await tester.pumpWidget(
        _host(const ListeningCaption(text: 'Mic is muted', animateDots: false)),
      );

      expect(find.text('Mic is muted'), findsOneWidget);
    });
  });

  group('VoiceControls', () {
    testWidgets('each button runs its action', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _host(
          VoiceControls(
            onKeyboard: () => taps.add('keyboard'),
            onMic: () => taps.add('mic'),
            onClose: () => taps.add('close'),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Type instead'));
      await tester.tap(find.byTooltip('Mute microphone'));
      await tester.tap(find.byTooltip('End voice and continue in chat'));

      expect(taps, ['keyboard', 'mic', 'close']);
    });

    testWidgets('a button without an action is inert and looks dimmed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(VoiceControls(onKeyboard: null, onMic: () => taps++, onClose: null)),
      );

      await tester.tap(find.byTooltip('Type instead'));
      await tester.pump(const Duration(milliseconds: 300));

      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_alt_outlined),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      expect(taps, 0);
    });

    testWidgets('a muted mic offers to unmute', (tester) async {
      await tester.pumpWidget(
        _host(
          VoiceControls(
            onKeyboard: () {},
            onMic: () {},
            onClose: () {},
            micOn: false,
          ),
        ),
      );

      expect(find.byTooltip('Unmute microphone'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
    });
  });

  testWidgets('GenerateLoading shows its label and a spinner', (tester) async {
    await tester.pumpWidget(_host(const GenerateLoading()));
    await _run(tester, 4);

    expect(find.text('Generating'), findsOneWidget);
    expect(find.byType(SparkSpinner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
