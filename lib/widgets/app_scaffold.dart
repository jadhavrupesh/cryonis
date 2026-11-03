import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A black screen with its content kept to a phone-width column, so the app
/// also looks right in a wide macOS window. An optional [backdrop] (the voice
/// glow) fills the whole window behind the column.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child, this.backdrop});

  final Widget child;
  final Widget? backdrop;

  static const maxContentWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.black,
        // The backdrop must not squash when the keyboard opens, so the
        // keyboard inset is applied to the content only.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            if (backdrop != null) Positioned.fill(child: backdrop!),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: math.min(constraints.maxWidth, maxContentWidth),
                    height: constraints.maxHeight,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(bottom: keyboard),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
