import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'code_block.dart';

/// Renders a model answer the way ChatGPT / Claude / Gemini do: headings,
/// bold / italic, lists, quotes, tables, links and highlighted code blocks.
/// Text streams in, so unfinished Markdown (an open code fence, a half
/// written table) must render sensibly while it grows.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  static final _body = AppText.answer;

  static TextStyle _heading(double size) => inter(
    size: size,
    weight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static final _styleSheet = MarkdownStyleSheet(
    p: _body,
    pPadding: EdgeInsets.zero,
    h1: _heading(21),
    h2: _heading(18.5),
    h3: _heading(16.5),
    h4: _heading(15.5),
    h5: _heading(15),
    h6: _heading(15),
    h1Padding: const EdgeInsets.only(top: 6),
    h2Padding: const EdgeInsets.only(top: 6),
    h3Padding: const EdgeInsets.only(top: 4),
    strong: inter(size: 14, weight: FontWeight.w600),
    em: const TextStyle(fontStyle: FontStyle.italic),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    a: const TextStyle(
      color: AppColors.accentStrong,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.accentSoft,
    ),
    code: AppText.mono.copyWith(
      fontSize: 13,
      color: AppColors.accent,
      backgroundColor: const Color(0x26FFFFFF),
    ),
    blockSpacing: 12,
    listIndent: 22,
    listBullet: _body,
    listBulletPadding: const EdgeInsets.only(right: 4),
    blockquote: _body.copyWith(color: AppColors.text2),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 2, 0, 2),
    blockquoteDecoration: const BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.accentSoft, width: 3)),
    ),
    // Code blocks draw their own frame (see CodeBlock).
    codeblockPadding: EdgeInsets.zero,
    codeblockDecoration: const BoxDecoration(),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.glassBorder)),
    ),
    tableHead: _body.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
    tableBody: _body.copyWith(fontSize: 13.5),
    tableBorder: TableBorder.all(
      color: const Color(0x26FFFFFF),
      borderRadius: BorderRadius.circular(10),
    ),
    tableColumnWidth: const IntrinsicColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static final _builders = <String, MarkdownElementBuilder>{
    'pre': _CodeBlockBuilder(),
  };

  static Future<void> _open(String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      styleSheet: _styleSheet,
      builders: _builders,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      softLineBreak: true,
      onTapLink: (text, href, title) => _open(href),
    );
  }
}

/// Turns fenced code (`pre > code.language-x`) into a [CodeBlock].
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final className = code?.attributes['class'] ?? '';
    final language = className.startsWith('language-')
        ? className.substring('language-'.length)
        : null;
    final text = (code ?? element).textContent.replaceFirst(RegExp(r'\n$'), '');
    return CodeBlock(code: text, language: language);
  }
}
