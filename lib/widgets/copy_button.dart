import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Copies [text] to the clipboard and briefly turns into a "Copied" tick.
/// Icon-only when [label] is null.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.label,
    this.iconSize = 18,
  });

  final String text;
  final String? label;
  final double iconSize;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _copied
        ? AppColors.accentStrong
        : Colors.white.withValues(alpha: 0.6);
    final label = widget.label;

    return Tooltip(
      message: 'Copy',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _copy,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                size: widget.iconSize,
                color: color,
              ),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  _copied ? 'Copied' : label,
                  style: TextStyle(color: color, fontSize: 12.5, height: 1.1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
