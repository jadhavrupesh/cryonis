import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

/// What was saved: the messages and when they last changed.
class SavedConversation {
  const SavedConversation(this.messages, this.lastActivity);

  final List<ChatMessage> messages;
  final DateTime? lastActivity;
}

/// Saves the open conversation.
///
/// Writes go through one queue, so they can never overlap or finish out of
/// order, and a newer snapshot replaces an older one that has not started yet.
/// Replacing the conversation (a new chat right after clearing the old one) is
/// therefore a single write of the new text, never "remove, then set".
///
/// With an [imagesDirectory] the attached pictures are stored there as files
/// named after their content, and the preference value keeps only a reference.
/// Without one (tests, or a platform with no suitable folder) pictures stay
/// inline as base64, which is how older versions saved them; such a
/// conversation is moved to files the next time it is saved.
class ConversationStore {
  ConversationStore(this._prefs, {Directory? imagesDirectory})
    : _images = imagesDirectory;

  static const conversationKey = 'chat_messages_v1';
  static const activityKey = 'chat_last_activity_v1';

  final SharedPreferences _prefs;
  final Directory? _images;

  /// The file name already chosen for a picture, so its bytes are hashed once.
  final Expando<String> _names = Expando<String>('conversation image file');
  static final RegExp _fileName = RegExp(r'^[0-9a-f]{64}\.img$');

  _Write? _pending;
  Future<void>? _draining;

  /// Reads the saved conversation. Records that cannot be read are skipped, and
  /// pictures whose file is gone are dropped from their message.
  SavedConversation load() {
    final saved = _prefs.getString(conversationKey);
    if (saved == null) return const SavedConversation([], null);
    final activity = _prefs.getInt(activityKey);
    final lastActivity = activity == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(activity);
    final messages = <ChatMessage>[];
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! List<dynamic>) throw const FormatException();
      for (final value in decoded) {
        try {
          if (value is Map<String, dynamic>) {
            messages.add(ChatMessage.fromJson(_inflate(value)));
          }
        } on FormatException {
          // A single corrupt record should not hide the valid conversation.
        } on TypeError {
          // Nested attachment data can also be malformed; skip that record.
        }
      }
    } on FormatException {
      unawaited(_prefs.remove(conversationKey));
    }
    return SavedConversation(messages, lastActivity);
  }

  /// Queues [messages] as the saved conversation.
  void save(List<ChatMessage> messages, DateTime activity) {
    _pending = _Write(List.of(messages), activity);
    _draining ??= _drain();
  }

  /// Queues removal of the saved conversation and its picture files.
  void clear() {
    _pending = const _Write(null, null);
    _draining ??= _drain();
  }

  /// Completes when everything queued so far has been written.
  Future<void> flush() async {
    while (_draining != null) {
      await _draining;
    }
  }

  Future<void> _drain() async {
    try {
      while (_pending != null) {
        final write = _pending!;
        _pending = null;
        try {
          await _apply(write);
        } catch (error, stack) {
          // Keep draining: a failed write must not block the ones after it.
          debugPrint('Saving the conversation failed: $error\n$stack');
        }
      }
    } finally {
      _draining = null;
    }
  }

  Future<void> _apply(_Write write) async {
    final messages = write.messages;
    if (messages == null) {
      await _prefs.remove(conversationKey);
      await _prefs.remove(activityKey);
      await _deleteUnreferencedImages(const {});
      return;
    }
    final referenced = <String>{};
    final encoded = <Map<String, dynamic>>[];
    for (final message in messages) {
      // An empty placeholder for a reply that has not started is not saved.
      if (message.content.isEmpty && message.images.isEmpty) continue;
      encoded.add(await _encode(message, referenced));
    }
    await _prefs.setString(conversationKey, jsonEncode(encoded));
    await _prefs.setInt(activityKey, write.activity!.millisecondsSinceEpoch);
    await _deleteUnreferencedImages(referenced);
  }

  Future<Map<String, dynamic>> _encode(
    ChatMessage message,
    Set<String> referenced,
  ) async {
    final json = message.toJson();
    if (_images == null || message.images.isEmpty) return json;
    final images = <Map<String, dynamic>>[];
    for (final image in message.images) {
      try {
        final file = await _fileFor(image);
        referenced.add(file);
        images.add({
          'name': image.name,
          'mimeType': image.mimeType,
          'file': file,
        });
      } on FileSystemException catch (error) {
        // Never lose a picture because the disk refused it: keep it inline.
        debugPrint('Could not store ${image.name} as a file: $error');
        images.add(image.toJson());
      }
    }
    json['images'] = images;
    return json;
  }

  /// The file holding [image]'s bytes, written first if it does not exist yet.
  Future<String> _fileFor(ChatImage image) async {
    final directory = _images!;
    final name = _names[image] ??=
        '${sha256.convert(utf8.encode(image.base64Data))}.img';
    final file = File('${directory.path}/$name');
    if (await file.exists()) return name;
    await directory.create(recursive: true);
    // Write beside it, then rename, so a crash never leaves half a picture.
    final partial = File('${file.path}.tmp');
    await partial.writeAsBytes(base64Decode(image.base64Data), flush: true);
    await partial.rename(file.path);
    return name;
  }

  Future<void> _deleteUnreferencedImages(Set<String> keep) async {
    final directory = _images;
    if (directory == null || !await directory.exists()) return;
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (keep.contains(name)) continue;
      if (_fileName.hasMatch(name) || name.endsWith('.img.tmp')) {
        try {
          await entry.delete();
        } on FileSystemException {
          // It will be tried again at the next save.
        }
      }
    }
  }

  /// Turns a saved message back into the form [ChatMessage.fromJson] reads,
  /// reading each referenced picture back from its file.
  Map<String, dynamic> _inflate(Map<String, dynamic> json) {
    final raw = json['images'];
    if (raw is! List<dynamic>) return json;
    final images = <Object?>[];
    for (final value in raw) {
      if (value is Map<String, dynamic> && value['file'] is String) {
        final data = _read(value['file'] as String);
        if (data == null) continue; // the file is missing: drop the picture
        images.add({
          'name': value['name'],
          'mimeType': value['mimeType'],
          'base64Data': data,
        });
      } else {
        images.add(value);
      }
    }
    return {...json, 'images': images};
  }

  String? _read(String name) {
    final directory = _images;
    // Only names this class writes are read, never a path from saved data.
    if (directory == null || !_fileName.hasMatch(name)) return null;
    try {
      return base64Encode(File('${directory.path}/$name').readAsBytesSync());
    } on FileSystemException {
      return null;
    }
  }
}

class _Write {
  const _Write(this.messages, this.activity);

  /// The messages to save, or null to remove the saved conversation.
  final List<ChatMessage>? messages;
  final DateTime? activity;
}
