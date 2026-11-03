import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import '../theme/app_theme.dart';
import 'copy_button.dart';

/// A fenced code block as shown by ChatGPT / Claude: language label and copy
/// button in a header bar, syntax-highlighted code that scrolls sideways.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  static final _theme = {
    ...atomOneDarkTheme,
    'root': const TextStyle(
      color: Color(0xFFABB2BF),
      backgroundColor: Colors.transparent,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final name = language;
    final label = name == null || name.isEmpty ? 'code' : name;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xCC0A0807),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white.withValues(alpha: 0.06),
            padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
            child: Row(
              children: [
                Text(label, style: AppText.caption.copyWith(fontSize: 12.5)),
                const Spacer(),
                CopyButton(text: code, label: 'Copy', iconSize: 15),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: HighlightView(
              code,
              // HighlightView throws on a null language; unknown names fall
              // back to plain text inside the highlighter.
              language: name == null || name.isEmpty ? 'plaintext' : name,
              theme: _theme,
              textStyle: AppText.mono.copyWith(fontSize: 13.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
