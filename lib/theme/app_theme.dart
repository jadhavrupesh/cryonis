import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Warm grayscale colours sampled from the habit-tracker reference image (see
/// UI_SPEC.md): a pure black canvas, layered graphite surfaces and a soft
/// silver accent.
class AppColors {
  static const black = Color(0xFF000000);

  /// Header pill, chips, input card, user bubble.
  static const surface = Color(0xFF1D1D1C);

  /// Tool chips inside the input card.
  static const surface2 = Color(0xFF30302F);

  /// Primary action fill, with dark content for accessible contrast.
  static const accent = Color(0xFFC8C8C4);
  static const accentSoft = Color(0xFF9C9C98);
  static const accentStrong = Color(0xFFEEEEEA);
  static const accentMuted = Color(0xFF4B4B49);
  static const onAccent = Color(0xFF101010);

  static const text = Color(0xFFF2F2EF);
  static const textAi = Color(0xFFDEDEDA);
  static const text2 = Color(0xFFB8B8B4);
  static const text3 = Color(0xFF8A8A86);
  static const text4 = Color(0xFF767673);

  /// Voice-mode glow: graphite while idle, brighter silver while active.
  static const glowIdle = Color(0xFF20201F);
  static const glowActive = Color(0xFF5B5B58);

  /// Surfaces used by sheets and menus.
  static const glass = surface;
  static const glassStrong = Color(0xFF121212);
  static const glassBorder = Color(0x26FFFFFF);

  static const textDim = text3;
  static const error = Color(0xFFFF6B5E);
}

class AppGradients {
  /// The silver mic / send button: softly lit from the top-left.
  static const mic = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentStrong, AppColors.accentSoft],
  );
}

/// Inter, with the weight set through its variable `wght` axis so every weight
/// from one font file renders correctly on every platform.
TextStyle inter({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.text,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

class AppText {
  static final body = inter(size: 14, height: 1.45);

  /// Assistant answers.
  static final answer = inter(size: 14, color: AppColors.textAi, height: 1.5);

  static final caption = inter(size: 12, color: AppColors.text3, height: 1.2);

  /// Header pill, section chips, list rows.
  static final label = inter(size: 14, weight: FontWeight.w500);

  /// The live transcript in voice mode.
  static final transcript = inter(size: 18, height: 1.7);

  /// "I'm Listening…" in voice mode.
  static final voiceCaption = inter(
    size: 20,
    weight: FontWeight.w600,
    color: AppColors.text2,
    letterSpacing: -0.2,
  );

  /// Code and inline code. Menlo on Apple platforms, the system monospace
  /// font elsewhere.
  static const mono = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['SF Mono', 'Roboto Mono', 'Consolas', 'monospace'],
    fontSize: 14,
    height: 1.5,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accentStrong,
    onSecondary: AppColors.onAccent,
    surface: AppColors.black,
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.black,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accentStrong,
      selectionColor: Color(0x66C8C8C4),
      selectionHandleColor: AppColors.accentStrong,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      contentTextStyle: inter(size: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

const overlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);
