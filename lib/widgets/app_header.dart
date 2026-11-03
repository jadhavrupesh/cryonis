import 'package:flutter/material.dart';

import '../state/chat_controller.dart';
import '../state/chat_scope.dart';
import '../theme/app_theme.dart';
import 'planet_orb.dart';
import 'sheets.dart';

/// The top row of every screen: menu · `model ⌄` pill · avatar.
///
/// The menu opens the server settings, the pill picks the Ollama model, and the
/// avatar carries a status dot for the connection (tap to check it again).
/// With [interactive] false (during a call) the row is purely visual.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.interactive = true, this.onBack});

  final bool interactive;

  /// Shows a back arrow instead of the menu (used by the chat screen).
  final VoidCallback? onBack;

  Future<void> _checkConnection(BuildContext context) async {
    final chat = ChatScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    await chat.refreshModels();

    final count = chat.models.length;
    final message = chat.connection == Connection.online
        ? 'Connected to Ollama · $count model${count == 1 ? '' : 's'}'
        : chat.connectionError ?? 'Not connected to Ollama';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.maybeOf(context);
    final status = switch (chat?.connection) {
      Connection.online => const Color(0xFF5BD68A),
      Connection.offline => AppColors.error,
      Connection.checking => const Color(0xFFFFC53D),
      null => AppColors.text4,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        height: 41,
        child: Row(
          children: [
            SizedBox(
              width: 41,
              child: onBack != null
                  ? Tooltip(
                      message: 'Back',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onBack,
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Color(0xFF8E8E8E),
                          ),
                        ),
                      ),
                    )
                  : Tooltip(
                      message: 'Server settings',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: interactive && chat != null
                            ? () => showServerSettings(context)
                            : null,
                        child: const Align(
                          alignment: Alignment.centerLeft,
                          child: _MenuGlyph(),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Center(
                child: IgnorePointer(
                  ignoring: !interactive,
                  child: const ModelChip(),
                ),
              ),
            ),
            SizedBox(
              width: 41,
              child: Tooltip(
                message: 'Check Ollama connection',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: interactive && chat != null
                      ? () => _checkConnection(context)
                      : null,
                  child: _Avatar(status: status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two short bars, as in the design.
class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph();

  @override
  Widget build(BuildContext context) {
    Widget bar() => Container(
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        color: const Color(0xFF8E8E8E),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [bar(), const SizedBox(height: 5), bar()],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.status});

  final Color status;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 41,
      height: 41,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 41,
            height: 41,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const PlanetOrb(size: 27, glow: false, animate: false),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status,
                border: Border.all(color: AppColors.black, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
