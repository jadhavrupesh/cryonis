import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'copy_button.dart';
import 'markdown_view.dart';
import 'voice_widgets.dart';

/// One message of the conversation. The user's text sits in a dark bubble on
/// the right; the assistant's answer is plain full-width Markdown with no bubble
/// (as in the design), "Generating ✳" under it while it streams, and copy /
/// regenerate actions underneath once it has finished.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onRetry,
    this.onRegenerate,
  });

  final ChatMessage message;

  /// This answer is still arriving.
  final bool isStreaming;

  /// Shown as "Tap to retry" on error messages.
  final VoidCallback? onRetry;

  /// Shown as a regenerate button under the latest finished answer.
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return message.role == ChatRole.user
        ? _UserBubble(message: message)
        : _AssistantMessage(
            message: message,
            isStreaming: isStreaming,
            onRetry: onRetry,
            onRegenerate: onRegenerate,
          );
  }
}

/// Shown while waiting for the first token of an answer.
class AssistantStatus extends StatelessWidget {
  const AssistantStatus({super.key});

  @override
  Widget build(BuildContext context) => const GenerateLoading();
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.images.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final image in message.images)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(image.base64Data),
                            width: 120,
                            height: 100,
                            fit: BoxFit.cover,
                            semanticLabel: image.name,
                          ),
                        ),
                    ],
                  ),
                if (message.images.isNotEmpty && message.content.isNotEmpty)
                  const SizedBox(height: 10),
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: inter(
                      size: 14,
                      weight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.isStreaming,
    this.onRetry,
    this.onRegenerate,
  });

  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onRetry;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final isError = message.isError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isError)
          _ErrorNotice(text: message.content, onRetry: onRetry)
        else
          MarkdownView(message.content),
        if (isStreaming && !isError)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: GenerateLoading(),
          ),
        if (!isStreaming && !isError)
          // The buttons carry 8px of padding; pull them back so their icons
          // line up with the text edge.
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CopyButton(text: message.content),
                if (onRegenerate != null)
                  _ActionIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Regenerate',
                    onPressed: onRegenerate!,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.text3),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppText.body.copyWith(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: const Text(
                'Tap to retry',
                style: TextStyle(
                  color: AppColors.accentStrong,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
