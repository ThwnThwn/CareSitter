import 'dart:async';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const chatFirestoreReadEnabled =
    bool.fromEnvironment('CHAT_FIRESTORE_READ_ENABLED', defaultValue: false);

final chatFirestoreReaderProvider = Provider<ChatFirestoreReader?>((ref) {
  if (!chatFirestoreReadEnabled) return null;
  final auth = ref.read(authStateProvider.notifier);
  final reader = ChatFirestoreReader(
    ref.read(dioClientProvider),
    () => ref.read(authStateProvider).valueOrNull?.userId,
  );
  Future<void> cleanup() => reader.clear();
  auth.registerLogoutCleanup(cleanup);
  ref.onDispose(() {
    auth.unregisterLogoutCleanup(cleanup);
    unawaited(reader.clear());
  });
  return reader;
});

class ChatFirestoreBatch {
  const ChatFirestoreBatch(this.items, this.hasMore, this.highWatermark);
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final int highWatermark;
}

/// A named Firebase app isolates each CareSitter login's in-memory cache.
/// Persistent Firestore cache is disabled for private chat on every platform.
class ChatFirestoreReader {
  ChatFirestoreReader(this._client, this._currentUserId);

  final DioClient _client;
  final String? Function() _currentUserId;
  FirebaseApp? _app;
  FirebaseFirestore? _database;
  String? _uid;
  int? _expiresAtMs;
  Future<void>? _opening;
  int _generation = 0;

  Future<void> _ensureSession() async {
    final uid = _currentUserId()?.toLowerCase();
    if (uid == null || uid.isEmpty) throw StateError('No CareSitter session.');
    if (_database != null &&
        _uid == uid &&
        (_expiresAtMs ?? 0) > DateTime.now().millisecondsSinceEpoch + 30000) {
      return;
    }
    if (_opening != null) await _opening;
    if (_database != null &&
        _uid == uid &&
        (_expiresAtMs ?? 0) > DateTime.now().millisecondsSinceEpoch + 30000) {
      return;
    }
    if (_database != null) await clear();
    final generation = _generation;
    final opening = _open(uid, generation);
    _opening = opening;
    try {
      await opening;
    } finally {
      if (identical(_opening, opening)) _opening = null;
    }
  }

  Future<void> _open(String uid, int generation) async {
    final defaultApps = Firebase.apps.where((app) => app.name == '[DEFAULT]');
    const configuredOptions = FirebaseOptions(
      apiKey: String.fromEnvironment('CHAT_FIREBASE_API_KEY'),
      appId: String.fromEnvironment('CHAT_FIREBASE_APP_ID'),
      messagingSenderId:
          String.fromEnvironment('CHAT_FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('CHAT_FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('CHAT_FIREBASE_AUTH_DOMAIN'),
    );
    final firebaseOptions =
        defaultApps.isNotEmpty ? defaultApps.first.options : configuredOptions;
    if (firebaseOptions.apiKey.isEmpty ||
        firebaseOptions.appId.isEmpty ||
        firebaseOptions.projectId.isEmpty) {
      throw StateError('Firebase chat is not configured.');
    }
    final expectedPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    final appIdParts = firebaseOptions.appId.split(':');
    if (!kIsWeb &&
        expectedPlatform != null &&
        (appIdParts.length < 4 || appIdParts[2] != expectedPlatform)) {
      // Native Firebase aborts the process for a web/other-platform App ID.
      // Let the repository fall back to the authorized PostgreSQL API.
      throw StateError('Firebase chat App ID does not match this platform.');
    }
    final response =
        await _client.post<Map<String, dynamic>>('/chat/firestore-session');
    final data = response.data;
    final token = data?['customToken']?.toString();
    final projectId = data?['projectId']?.toString();
    final expiresAtMs = (data?['expiresAtMs'] as num?)?.toInt();
    if (data?['uid']?.toString().toLowerCase() != uid ||
        token == null ||
        token.isEmpty ||
        projectId != firebaseOptions.projectId ||
        expiresAtMs == null ||
        expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError(
          'Firebase chat session does not match the CareSitter user.');
    }
    if (generation != _generation || _currentUserId()?.toLowerCase() != uid) {
      throw StateError('CareSitter session changed.');
    }
    final app = await Firebase.initializeApp(
      name: 'chat-read-${DateTime.now().microsecondsSinceEpoch}',
      options: firebaseOptions,
    );
    FirebaseFirestore? database;
    try {
      database = FirebaseFirestore.instanceFor(app: app);
      database.settings = const Settings(persistenceEnabled: false);
      final auth = FirebaseAuth.instanceFor(app: app);
      if (kIsWeb) await auth.setPersistence(Persistence.NONE);
      await auth.signInWithCustomToken(token);
      if (generation != _generation || _currentUserId()?.toLowerCase() != uid) {
        throw StateError('CareSitter session changed.');
      }
      _app = app;
      _database = database;
      _uid = uid;
      _expiresAtMs = expiresAtMs;
    } catch (_) {
      await _disposeApp(app, database);
      rethrow;
    }
  }

  Future<ChatFirestoreBatch> messages({
    required String type,
    required String conversationId,
    required String epochId,
    int? afterSequence,
    int? beforeSequence,
    int? expectedVersion,
    int? expectedHighWatermark,
    int? maxSequence,
    int limit = 50,
  }) async {
    await _ensureSession();
    final database = _database!;
    final generation = _generation;
    final uid = _uid!;
    final conversation = await database
        .collection('chatConversations')
        .doc(conversationId)
        .get(const GetOptions(source: Source.server));
    final state = conversation.data();
    if (state == null ||
        state['type'] != type ||
        state['readEnabled'] != true ||
        (expectedVersion != null &&
            ((state['changeVersion'] as num?)?.toInt() ?? -1) <
                expectedVersion)) {
      throw StateError('Firestore chat projection is not current.');
    }
    final projectedHigh = (state['lastSequence'] as num?)?.toInt() ?? -1;
    if (projectedHigh < 0 ||
        (expectedHighWatermark != null &&
            projectedHigh < expectedHighWatermark) ||
        (maxSequence != null && projectedHigh < maxSequence)) {
      throw StateError('Firestore chat projection is behind PostgreSQL.');
    }
    final high = maxSequence ?? projectedHigh;
    final collection = database
        .collection('chatConversations')
        .doc(conversationId)
        .collection('epochs')
        .doc(epochId)
        .collection('messages');
    final descending = afterSequence == null;
    Query<Map<String, dynamic>> query = collection
        .orderBy('sequence', descending: descending)
        .where('sequence', isLessThanOrEqualTo: high);
    if (afterSequence != null) {
      query = query.where('sequence', isGreaterThan: afterSequence);
    } else if (beforeSequence != null) {
      query = query.where('sequence', isLessThan: beforeSequence);
    }
    final size = limit.clamp(1, 99);
    final snapshot = await query
        .limit(size + 1)
        .get(const GetOptions(source: Source.server));
    if (generation != _generation ||
        _uid != uid ||
        _currentUserId()?.toLowerCase() != uid) {
      throw StateError('CareSitter session changed while reading chat.');
    }
    final docs = snapshot.docs.take(size).toList(growable: false);
    final items = docs
        .map((doc) => <String, dynamic>{
              ...doc.data(),
              'epochId': epochId,
              'isMine': doc.data()['senderUserId'] == uid,
            })
        .toList(growable: false);
    if (items.isEmpty &&
        high > (afterSequence ?? 0) &&
        beforeSequence == null) {
      throw StateError('Firestore chat messages are incomplete.');
    }
    for (var index = 0; index < items.length; index++) {
      final sequence = (items[index]['sequence'] as num?)?.toInt();
      final expected = index == 0
          ? afterSequence != null
              ? afterSequence + 1
              : beforeSequence != null
                  ? beforeSequence - 1
                  : high
          : (items[index - 1]['sequence'] as num).toInt() +
              (descending ? -1 : 1);
      if (sequence != expected) {
        throw StateError('Firestore chat sequence has a gap.');
      }
    }
    if (snapshot.docs.length <= size &&
        items.isNotEmpty &&
        (items.last['sequence'] as num).toInt() != (descending ? 1 : high)) {
      throw StateError('Firestore chat messages are incomplete.');
    }
    return ChatFirestoreBatch(
        descending ? items.reversed.toList(growable: false) : items,
        snapshot.docs.length > size,
        high);
  }

  Future<void> clear() async {
    _generation++;
    final app = _app;
    final database = _database;
    _app = null;
    _database = null;
    _uid = null;
    _expiresAtMs = null;
    if (app == null) return;
    await _disposeApp(app, database);
  }

  Future<void> _disposeApp(FirebaseApp app, FirebaseFirestore? database) async {
    try {
      await FirebaseAuth.instanceFor(app: app).signOut();
    } finally {
      try {
        await database?.terminate();
      } finally {
        await app.delete();
      }
    }
  }
}
