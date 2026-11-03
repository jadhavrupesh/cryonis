enum ChatRole { user, assistant }

/// An image sent alongside a user prompt. Ollama's `/api/chat` accepts the
/// base64 payload in the message's `images` array.
class ChatImage {
  const ChatImage({
    required this.name,
    required this.mimeType,
    required this.base64Data,
  });

  final String name;
  final String mimeType;
  final String base64Data;

  factory ChatImage.fromJson(Map<String, dynamic> json) => switch (json) {
    {
      'name': String name,
      'mimeType': String mimeType,
      'base64Data': String base64Data,
    } =>
      ChatImage(name: name, mimeType: mimeType, base64Data: base64Data),
    _ => throw const FormatException('Invalid chat image.'),
  };

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'base64Data': base64Data,
  };
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isError = false,
    this.images = const [],
  });

  final ChatRole role;
  final String content;

  /// An assistant-side failure notice; never sent back to the model.
  final bool isError;
  final List<ChatImage> images;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'];
    final content = json['content'];
    final isError = json['isError'];
    final rawImages = json['images'];
    if (roleName is! String ||
        content is! String ||
        (isError != null && isError is! bool) ||
        (rawImages != null && rawImages is! List<dynamic>)) {
      throw const FormatException('Invalid chat message.');
    }
    final role = ChatRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) throw const FormatException('Invalid chat role.');
    return ChatMessage(
      role: role,
      content: content,
      isError: isError as bool? ?? false,
      images: [
        for (final image in rawImages as List<dynamic>? ?? const [])
          ChatImage.fromJson(image as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'content': content,
    if (isError) 'isError': true,
    if (images.isNotEmpty)
      'images': [for (final image in images) image.toJson()],
  };

  ChatMessage copyWith({
    String? content,
    bool? isError,
    List<ChatImage>? images,
  }) => ChatMessage(
    role: role,
    content: content ?? this.content,
    isError: isError ?? this.isError,
    images: images ?? this.images,
  );
}
