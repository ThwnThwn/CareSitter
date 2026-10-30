import 'dart:async';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_realtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final bookingChatControllerProvider = StateNotifierProvider.autoDispose
    .family<BookingChatController, BookingChatState, String>((ref, bookingId) {
  ref.watch(authStateProvider.select((value) => (
        value.valueOrNull?.userId,
        value.valueOrNull?.isAuthenticated == true,
      )));
  return BookingChatController(
    bookingId: bookingId,
    repository: ref.read(bookingChatRepositoryProvider),
    realtime: BookingChatRealtime(ref.read(careSignalRProvider)),
  );
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BookingChatState {
  const BookingChatState({
    this.loading = true,
    this.busy = false,
    this.error,
    this.meta,
    this.messages = const [],
    this.previousCursor,
    this.hasMoreBefore = false,
  });

  final bool loading;
  final bool busy;
  final String? error;
  final BookingChatMeta? meta;
  final List<BookingChatMessage> messages;
  final String? previousCursor;
  final bool hasMoreBefore;

  int get unreadCount => meta?.unreadCount ?? 0;
  bool get canSend => meta?.canSend == true;
  bool get canRead => meta?.canRead == true;
  bool get featureEnabled => meta?.featureEnabled == true;
  bool get hasChat => meta?.hasChat == true;

  BookingChatState copyWith({
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    BookingChatMeta? meta,
    List<BookingChatMessage>? messages,
    String? previousCursor,
    bool clearPreviousCursor = false,
    bool? hasMoreBefore,
  }) =>
      BookingChatState(
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        meta: meta ?? this.meta,
        messages: messages ?? this.messages,
        previousCursor:
            clearPreviousCursor ? null : previousCursor ?? this.previousCursor,
        hasMoreBefore: hasMoreBefore ?? this.hasMoreBefore,
      );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class BookingChatController extends StateNotifier<BookingChatState> {
  BookingChatController({
    required this.bookingId,
    required this.repository,
    required this.realtime,
  }) : super(const BookingChatState()) {
    _realtimeSub = realtime.changes.listen((_) => unawaited(refresh()));
    unawaited(refresh());
    _startTimer();
  }

  final String bookingId;
  final BookingChatRepositoryPort repository;
  final BookingChatRealtimePort realtime;

  StreamSubscription<void>? _realtimeSub;
  Timer? _timer;
  Future<void>? _refreshTask;
  bool _active = true;
  int _accessGeneration = 0;

  String? _sendPayload;
  String? _sendKey;
  String? _quickPayload;
  String? _quickKey;
  String? _nextCursor;
  String? _lastReadMessageId;

  void _clearConversation({BookingChatMeta? meta, String? error}) {
    _accessGeneration++;
    _sendPayload = null;
    _sendKey = null;
    _quickPayload = null;
    _quickKey = null;
    _nextCursor = null;
    _lastReadMessageId = null;
    state = BookingChatState(
      loading: false,
      error: error,
      meta: meta,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => unawaited(refresh()));
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (active) {
      _startTimer();
      unawaited(refresh());
    } else {
      _timer?.cancel();
      unawaited(realtime.disconnect());
    }
  }

  Future<void> refresh() => !_active
      ? Future<void>.value()
      : _refreshTask ??= _reload().whenComplete(() {
          _refreshTask = null;
        });

  Future<void> _reload() async {
    try {
      final previousMeta = state.meta;
      final meta = await repository.metadata(bookingId);
      if (!mounted) return;

      if (!meta.featureEnabled || !meta.canRead) {
        _clearConversation(meta: meta);
        unawaited(realtime.disconnect());
        return;
      }

      final accessScopeChanged = previousMeta != null &&
          (previousMeta.conversationId != meta.conversationId ||
              previousMeta.currentEpochId != meta.currentEpochId ||
              previousMeta.scopeVersion != meta.scopeVersion);
      if (accessScopeChanged) {
        _clearConversation(meta: meta);
      }

      final initialLoad =
          accessScopeChanged || state.messages.isEmpty || _nextCursor == null;
      var page = initialLoad
          ? await repository.messages(bookingId, limit: 50)
          : await repository.messages(bookingId,
              afterCursor: _nextCursor, limit: 50);
      final incoming = <BookingChatMessage>[...page.items];
      while (!initialLoad && page.hasMoreAfter) {
        final cursor = page.nextCursor;
        if (cursor == null || cursor == _nextCursor) {
          throw StateError('Cursor phân trang tin nhắn không tiến lên.');
        }
        _nextCursor = cursor;
        page = await repository.messages(bookingId,
            afterCursor: _nextCursor, limit: 50);
        incoming.addAll(page.items);
      }
      if (!mounted) return;
      _nextCursor = page.nextCursor;

      final current =
          accessScopeChanged ? const <BookingChatMessage>[] : state.messages;
      final bySeq = <int, BookingChatMessage>{
        for (final m in current) m.sequence: m,
        for (final m in incoming) m.sequence: m,
      };
      final sorted = bySeq.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      state = state.copyWith(
        meta: meta,
        loading: false,
        clearError: true,
        messages: sorted,
        hasMoreBefore: initialLoad ? page.hasMoreBefore : state.hasMoreBefore,
        previousCursor:
            initialLoad ? page.previousCursor : state.previousCursor,
      );

      if (meta.conversationId != null && _active) {
        unawaited(realtime.connect(bookingId));
      }
    } catch (error) {
      if (!mounted) return;
      _clearConversation(error: error.toString());
      unawaited(realtime.disconnect());
    }
  }

  Future<void> loadMore() async {
    if (state.busy || !state.hasMoreBefore) return;
    final cursor = state.previousCursor;
    if (cursor == null) return;
    final accessGeneration = _accessGeneration;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final page =
          await repository.messages(bookingId, beforeCursor: cursor, limit: 50);
      if (!mounted || accessGeneration != _accessGeneration) return;
      final bySeq = <int, BookingChatMessage>{
        for (final m in page.items) m.sequence: m,
        for (final m in state.messages) m.sequence: m,
      };
      final sorted = bySeq.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      state = state.copyWith(
        busy: false,
        messages: sorted,
        hasMoreBefore: page.hasMoreBefore,
        previousCursor: page.previousCursor,
      );
    } catch (error) {
      if (mounted && accessGeneration == _accessGeneration) {
        state = state.copyWith(busy: false, error: error.toString());
      }
    }
  }

  Future<void> markVisibleRead() async {
    final meta = state.meta;
    final msgs = state.messages;
    if (!_active ||
        meta == null ||
        meta.currentEpochId == null ||
        msgs.isEmpty) {
      return;
    }
    final lastMsg = msgs.last;
    if (lastMsg.id == _lastReadMessageId) return;
    if (lastMsg.sequence <= meta.lastReadSequence) return;
    _lastReadMessageId = lastMsg.id;
    try {
      await repository.markRead(bookingId, meta.currentEpochId!, lastMsg.id);
    } catch (_) {
      if (_lastReadMessageId == lastMsg.id) _lastReadMessageId = null;
    }
  }

  Future<void> sendText(String text) async {
    final meta = state.meta;
    final clean = text.trim();
    if (meta == null || !meta.canSend || state.busy || clean.isEmpty) return;
    if (meta.currentEpochId == null) return;

    if (_sendPayload != clean) {
      _sendPayload = clean;
      _sendKey = const Uuid().v4();
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.sendText(
          bookingId, meta.currentEpochId!, clean, _sendKey!);
      if (!mounted) return;
      _sendKey = null;
      _sendPayload = null;
      await refresh();
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> sendQuick(BookingChatTemplate template,
      {Map<String, String>? params}) async {
    final meta = state.meta;
    if (meta == null || !meta.canSend || state.busy) return;
    if (meta.currentEpochId == null) return;
    final sortedParams = params?.entries.toList()
      ?..sort((a, b) => a.key.compareTo(b.key));
    final payload = '${template.key}:${template.version}:'
        '${sortedParams?.map((entry) => '${entry.key}=${entry.value}').join('&') ?? ''}';
    if (_quickPayload != payload) {
      _quickPayload = payload;
      _quickKey = const Uuid().v4();
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.sendQuick(bookingId, meta.currentEpochId!, template.key,
          template.version, _quickKey!,
          params: params);
      if (!mounted) return;
      _quickPayload = null;
      _quickKey = null;
      await refresh();
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<bool> reportMessage(String messageId, String reason) async {
    final clean = reason.trim();
    if (state.busy || messageId.isEmpty || clean.isEmpty) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.reportMessage(bookingId, messageId, clean);
      return true;
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
      return false;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<bool> setBlocked(bool blocked) async {
    if (state.busy || state.meta?.hasChat != true) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.setBlocked(bookingId, blocked);
      await refresh();
      return true;
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
      return false;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_realtimeSub?.cancel());
    realtime.dispose();
    super.dispose();
  }
}
