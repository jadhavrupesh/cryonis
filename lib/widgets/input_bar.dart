import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/image_attachment_picker.dart';
import '../theme/app_theme.dart';
import 'voice_widgets.dart';

/// The "Ask anything" card on the home screen: text, then `+` and the mic.
class HomeInputPanel extends StatefulWidget {
  const HomeInputPanel({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onMic,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<List<ChatImage>> onSubmit;
  final VoidCallback onMic;
  final FocusNode? focusNode;

  @override
  State<HomeInputPanel> createState() => _HomeInputPanelState();
}

class _HomeInputPanelState extends State<HomeInputPanel> {
  final List<ChatImage> _images = [];

  Future<void> _pick() async {
    try {
      final selected = await pickImageAttachments(
        remaining: maxChatImages - _images.length,
      );
      if (mounted) setState(() => _images.addAll(selected));
    } on ImageAttachmentException catch (error) {
      if (mounted) _showAttachmentError(context, error.message);
    }
  }

  void _submit() {
    if (widget.controller.text.trim().isEmpty && _images.isEmpty) return;
    widget.onSubmit(List.unmodifiable(_images));
    setState(_images.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            minLines: 2,
            maxLines: 6,
            style: AppText.body,
            cursorColor: AppColors.accentStrong,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration.collapsed(
              hintText: 'Ask anything',
              hintStyle: AppText.body.copyWith(color: AppColors.text3),
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttachmentStrip(
              images: _images,
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _PlusButton(onPressed: _pick),
              const Spacer(),
              _MicOrSend(
                controller: widget.controller,
                hasImages: _images.isNotEmpty,
                onSend: _submit,
                onMic: widget.onMic,
                hero: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The compact input under the conversation: `+`, the text, then mic / send /
/// stop.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isStreaming,
    required this.onSubmit,
    required this.onMic,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final ValueChanged<List<ChatImage>> onSubmit;
  final VoidCallback onMic;
  final VoidCallback onStop;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final List<ChatImage> _images = [];

  Future<void> _pick() async {
    try {
      final selected = await pickImageAttachments(
        remaining: maxChatImages - _images.length,
      );
      if (mounted) setState(() => _images.addAll(selected));
    } on ImageAttachmentException catch (error) {
      if (mounted) _showAttachmentError(context, error.message);
    }
  }

  void _submit() {
    if (widget.isStreaming ||
        (widget.controller.text.trim().isEmpty && _images.isEmpty)) {
      return;
    }
    widget.onSubmit(List.unmodifiable(_images));
    setState(_images.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_images.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AttachmentStrip(
                images: _images,
                onRemove: (index) => setState(() => _images.removeAt(index)),
              ),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PlusButton(onPressed: widget.isStreaming ? null : _pick),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 4,
                    style: AppText.body,
                    cursorColor: AppColors.accentStrong,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Ask anything',
                      hintStyle: AppText.body.copyWith(color: AppColors.text3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.isStreaming)
                _SquareAction(
                  icon: Icons.stop_rounded,
                  tooltip: 'Stop',
                  onPressed: widget.onStop,
                )
              else
                _MicOrSend(
                  controller: widget.controller,
                  hasImages: _images.isNotEmpty,
                  onSend: _submit,
                  onMic: widget.onMic,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The `+` that attaches an image.
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Attach image',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 19,
              color: AppColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A 32 dp silver rounded square with an icon: send, stop.
class _SquareAction extends StatelessWidget {
  const _SquareAction({
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
        child: AccentMic(size: 32, radius: 6, icon: icon, iconSize: 18),
      ),
    );
  }
}

/// Mic while the field is empty, send once there is text.
class _MicOrSend extends StatelessWidget {
  const _MicOrSend({
    required this.controller,
    required this.hasImages,
    required this.onSend,
    required this.onMic,
    this.hero = false,
  });

  final TextEditingController controller;
  final bool hasImages;
  final VoidCallback onSend;
  final VoidCallback onMic;

  /// The mic flies into the voice screen (only one mic per screen may do this).
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.trim().isNotEmpty || hasImages) {
          return _SquareAction(
            icon: Icons.arrow_upward_rounded,
            tooltip: 'Send',
            onPressed: onSend,
          );
        }
        final mic = Tooltip(
          message: 'Speak',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMic,
            child: const AccentMic(size: 32, radius: 6, iconSize: 18),
          ),
        );
        return hero
            ? MicHero(
                squareRadius: 6,
                circleRadius: 26.5,
                isCircle: false,
                child: mic,
              )
            : mic;
      },
    );
  }
}

class _AttachmentStrip extends StatelessWidget {
  const _AttachmentStrip({required this.images, required this.onRemove});

  final List<ChatImage> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(image.base64Data),
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  semanticLabel: image.name,
                ),
              ),
              Positioned(
                right: -5,
                top: -5,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _showAttachmentError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
