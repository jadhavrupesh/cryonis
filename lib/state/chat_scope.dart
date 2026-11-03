import 'package:flutter/widgets.dart';

import 'chat_controller.dart';

/// Makes the [ChatController] available to every screen and rebuilds
/// dependents when it changes.
class ChatScope extends InheritedNotifier<ChatController> {
  const ChatScope({
    super.key,
    required ChatController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Watches the controller; the caller rebuilds on every change.
  static ChatController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatScope>()!.notifier!;

  /// Like [of], but null when there is no scope above (an isolated screen).
  static ChatController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatScope>()
      ?.notifier;

  /// Reads the controller without subscribing, e.g. from `initState` or
  /// event handlers.
  static ChatController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatScope>()!.notifier!;
}
