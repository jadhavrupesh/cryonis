import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/chat_controller.dart';
import '../state/chat_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/input_bar.dart';
import 'voice_flow.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatController _chat;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _chat = ChatScope.read(context);
    _lastCount = _chat.messages.length;
    _chat.addListener(_followConversation);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToEnd(animate: false),
    );
  }

  @override
  void dispose() {
    _chat.removeListener(_followConversation);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest text in view, unless the user scrolled up to read.
  void _followConversation() {
    final grew = _chat.messages.length != _lastCount;
    _lastCount = _chat.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (grew || position.maxScrollExtent - position.pixels < 160) {
        _scrollToEnd(animate: grew);
      }
    });
  }

  void _scrollToEnd({required bool animate}) {
    if (!_scroll.hasClients) return;
    final end = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(
        end,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(end);
    }
  }

  void _submit(List<ChatImage> images) {
    if (_chat.isStreaming || (_input.text.trim().isEmpty && images.isEmpty)) {
      return;
    }
    final text = _input.text;
    _input.clear();
    _chat.send(text, images: images);
  }

  Future<void> _speak() async {
    final outcome = await openVoice(context);
    if (!mounted || outcome == null) return;
    switch (outcome) {
      case VoiceText(:final text):
        _chat.send(text);
      case VoiceConversation(:final turns):
        _chat.addConversation(turns);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = ChatScope.of(context);
    final messages = chat.messages;
    final last = messages.length - 1;

    return AppScaffold(
      child: Column(
        children: [
          AppHeader(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            // Messages fade out at the top and bottom instead of being cut off
            // with a hard edge under the pill and above the input.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 0.035, 0.97, 1],
              ).createShader(bounds),
              // One selection area so text can be selected across messages.
              child: SelectionArea(
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 22),
                  itemBuilder: (context, i) {
                    final message = messages[i];
                    final isLast = i == last;
                    if (isLast && chat.isWorking) {
                      return const AssistantStatus();
                    }

                    final streaming = isLast && chat.isStreaming;
                    return ChatBubble(
                      message: message,
                      isStreaming: streaming,
                      onRetry: isLast && message.isError ? chat.retry : null,
                      onRegenerate:
                          isLast &&
                              !streaming &&
                              !message.isError &&
                              message.role == ChatRole.assistant
                          ? chat.regenerate
                          : null,
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: ChatInputBar(
              controller: _input,
              isStreaming: chat.isStreaming,
              onSubmit: _submit,
              onMic: _speak,
              onStop: chat.stop,
            ),
          ),
        ],
      ),
    );
  }
}
