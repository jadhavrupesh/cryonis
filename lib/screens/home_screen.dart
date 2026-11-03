import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/chat_scope.dart';
import '../theme/app_theme.dart';
import '../utils/relative_time.dart';
import '../widgets/app_header.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/input_bar.dart';
import 'chat_screen.dart';
import 'routes.dart';
import 'voice_flow.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Quick starts: they fill the input and leave the rest to the user.
  static const _quickActions = [
    _QuickAction(Icons.tune_rounded, 'Analyse', 'Analyse '),
    _QuickAction(Icons.content_cut_rounded, 'Summaries', 'Summarise '),
    _QuickAction(Icons.edit_note_rounded, 'Draft', 'Draft '),
    _QuickAction(Icons.bug_report_outlined, 'Debug', 'Help me debug '),
  ];

  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _startChat(
    String prompt, {
    List<ChatImage> images = const [],
  }) async {
    final text = prompt.trim();
    if (text.isEmpty && images.isEmpty) return;
    final chat = ChatScope.read(context);
    final navigator = Navigator.of(context);

    chat.reset();
    chat.send(text, images: images);
    _input.clear();
    await navigator.push<void>(fadeRoute<void>(const ChatScreen()));
  }

  Future<void> _resumeChat() async {
    await Navigator.of(context).push<void>(fadeRoute<void>(const ChatScreen()));
  }

  /// Carries on in the chat from the turns of a finished voice call.
  Future<void> _continueInChat(List<ChatMessage> turns) async {
    final chat = ChatScope.read(context);
    final navigator = Navigator.of(context);

    chat.reset();
    chat.addConversation(turns);
    await navigator.push<void>(fadeRoute<void>(const ChatScreen()));
  }

  Future<void> _startVoice() async {
    final outcome = await openVoice(context);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case VoiceText(:final text):
        _startChat(text);
      case VoiceConversation(:final turns):
        _continueInChat(turns);
    }
  }

  void _prefill(String lead) {
    _input.value = TextEditingValue(
      text: lead,
      selection: TextSelection.collapsed(offset: lead.length),
    );
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);
    final messages = chat.messages;
    final firstUserMessage = messages
        .where((message) => message.role == ChatRole.user)
        .map((message) => message.content.trim())
        .where((text) => text.isNotEmpty)
        .firstOrNull;

    return AppScaffold(
      child: Column(
        children: [
          const AppHeader(),
          const SizedBox(height: 20),
          if (chat.hasConversation) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SectionChip(
                  icon: Icons.history_rounded,
                  label: 'Previous conversations',
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ConversationRow(
              title: firstUserMessage ?? 'Conversation',
              when: chat.lastActivity,
              onTap: _resumeChat,
            ),
          ],
          const Spacer(),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _quickActions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _QuickChip(
                action: _quickActions[i],
                onTap: () => _prefill(_quickActions[i].lead),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: HomeInputPanel(
              controller: _input,
              focusNode: _inputFocus,
              onSubmit: (images) => _startChat(_input.text, images: images),
              onMic: _startVoice,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.lead);

  final IconData icon;
  final String label;

  /// What goes into the input when the chip is tapped.
  final String lead;
}

/// "Previous conversations": icon + label on a flat chip.
class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.text2),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: inter(size: 14, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of the previous-conversations list: title left, time right.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.title,
    required this.when,
    required this.onTap,
  });

  final String title;
  final DateTime? when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 10, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.replaceAll(RegExp(r'\s+'), ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: inter(size: 14, color: AppColors.text2),
              ),
            ),
            if (when != null) ...[
              const SizedBox(width: 12),
              Text(
                relativeTime(when!),
                style: inter(size: 12, color: AppColors.text4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 19, color: AppColors.text3),
            const SizedBox(width: 10),
            Text(
              action.label,
              style: inter(size: 14, color: const Color(0xFFB6B6B6)),
            ),
          ],
        ),
      ),
    );
  }
}
