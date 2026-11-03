import 'package:flutter/material.dart';

import '../services/app_licenses.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Cryonis's own licence (MIT) in full, with the licences of everything it is
/// built from one tap away. Flutter's own licence page lists well over a
/// hundred third-party entries (every package plus the engine's C++ libraries),
/// so it sits behind the app's licence instead of being the first thing seen.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late final Future<String> _licence = DefaultAssetBundle.of(
    context,
  ).loadString(appLicenseAsset);

  void _openThirdParty() => showLicensePage(
    context: context,
    applicationName: 'Cryonis',
    applicationLegalese: appLegalese,
  );

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              height: 41,
              child: Row(
                children: [
                  Tooltip(
                    message: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 41,
                        height: 41,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Color(0xFF8E8E8E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Licences',
                    style: inter(
                      size: 18,
                      weight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _licence,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Cryonis is released under the MIT License. '
                          'The full text is in the LICENSE file of the project.',
                          style: AppText.body,
                        );
                      }
                      final text = snapshot.data;
                      if (text == null) return const SizedBox(height: 120);
                      return _LicenceText(text: text);
                    },
                  ),
                  const SizedBox(height: 28),
                  _ThirdPartyTile(onTap: _openThirdParty),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The licence text with its 80-column hard line breaks joined, so it wraps to
/// the phone's width. Paragraph breaks (blank lines) are kept.
class _LicenceText extends StatelessWidget {
  const _LicenceText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' '))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Text(
            paragraphs[i],
            style: i == 0
                ? inter(size: 16, weight: FontWeight.w600)
                : AppText.body.copyWith(color: AppColors.text2),
          ),
        ],
      ],
    );
  }
}

class _ThirdPartyTile extends StatelessWidget {
  const _ThirdPartyTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Third-party licences',
                    style: inter(size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flutter, the packages Cryonis uses and the Inter font. '
                    'Their licences require these notices to stay with the app.',
                    style: AppText.caption.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.text3,
            ),
          ],
        ),
      ),
    );
  }
}
