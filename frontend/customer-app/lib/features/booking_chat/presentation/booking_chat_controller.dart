import 'dart:async';

import 'package:caresitter_customer/features/booking_chat/data/booking_chat_realtime.dart';
import 'package:caresitter_customer/features/booking_chat/data/booking_chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final bookingChatControllerProvider = StateNotifierProvider.autoDispose
    .family<BookingChatController, BookingChatState, String>((ref, bookingId) {
  return BookingChatController(
    bookingId: bookingId,
    repository: ref.read(bookingChatRepositoryProvider),
    realtime: BookingChatRealtime(ref),
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
    this.nextCursor,
    this.hasMoreBefore = false,
  });

  final bool loading;
  final bool busy;
  final String? error;
  final BookingChatMeta? meta;
  final List<BookingChatMessage> messages;
  final String? nextCursor;  // cursor để load trang cũ hơn (backward)
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
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMoreBefore,
  }) =>
      BookingChatState(
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        meta: meta ?? this.meta,
        messages: messages ?? this.messages,
        nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
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
    _realtimeSub =
        realtime.changes.listen((_) => unawaited(refresh()));
    unawaited(refresh());
    _startTimer();
  }

  final String bookingId;
  final BookingChatRepository repository;
  final BookingChatRealtime realtime;

  StreamSubscription<void>? _realtimeSub;
  Timer? _timer;
  Future<void>? _refreshTask;
  bool _active = true;

  String? _sendPayload;
  String? _sendKey;
  // Lưu lại messageId cuối đã mark-read để tránh gọi lặp.
  String? _lastReadMessageId;

  void _startTimer() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 15), (_) => unawaited(refresh()));
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
      final meta = await repository.metadata(bookingId);
      if (!mounted) return;

      if (!meta.featureEnabled || !meta.canRead) {
        state = state.copyWith(meta: meta, loading: false, clearError: true);
        unawaited(realtime.disconnect());
        return;
      }

      // Load tin nhắn mới nhất (không thay đổi cursor đã lưu cho backward)
      final page = await repository.messages(bookingId, limit: 50);
      if (!mounted) return;

      // Merge messages mới vào danh sách hiện có (dedup by sequence)
      final current = state.messages;
      final bySeq = <int, BookingChatMessage>{
        for (final m in current) m.sequence: m,
        for (final m in page.items) m.sequence: m,
      };
      final sorted = bySeq.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      state = state.copyWith(
        meta: meta,
        loading: false,
        clearError: true,
        messages: sorted,
        hasMoreBefore: page.hasMoreBefore,
        nextCursor: page.nextCursor ?? state.nextCursor,
      );

      // Kết nối SignalR khi có conversation
      if (meta.conversationId != null && _active) {
        unawaited(realtime.connect(bookingId));
      }
    } catch (error) {
      if (mounted) state = state.copyWith(loading: false, error: error.toString());
    }
  }

  /// Load trang cũ hơn (scroll up).
  Future<void> loadMore() async {
    if (state.busy || !state.hasMoreBefore) return;
    final cursor = state.nextCursor;
    if (cursor == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final page = await repository.messages(bookingId,
          beforeCursor: cursor, limit: 50);
      if (!mounted) return;
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
        nextCursor: page.previousCursor,
      );
    } catch (error) {
      if (mounted) state = state.copyWith(busy: false, error: error.toString());
    }
  }

  /// Đánh dấu đọc đến message hiện tại cuối màn hình.
  Future<void> markVisibleRead() async {
    final meta = state.meta;
    final msgs = state.messages;
    if (!_active || meta == null || meta.currentEpochId == null ||
        msgs.isEmpty) return;
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

  /// Gửi tin văn bản.
  Future<void> sendText(String text) async {
    final meta = state.meta;
    final clean = text.trim();
    if (meta == null || !meta.canSend || state.busy || clean.isEmpty) return;
    if (meta.currentEpochId == null) return;

    // Idempotency: nếu payload khác → key mới
    if (_sendPayload != clean) {
      _sendPayload = clean;
      _sendKey = const Uuid().v4();
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.sendText(bookingId, meta.currentEpochId!, clean, _sendKey!);
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

  /// Gửi quick message từ template.
  Future<void> sendQuick(BookingChatTemplate template,
      {Map<String, String>? params}) async {
    final meta = state.meta;
    if (meta == null || !meta.canSend || state.busy) return;
    if (meta.currentEpochId == null) return;
    final key = const Uuid().v4();
    state = state.copyWith(busy: true, clearError: true);
    try {
      await repository.sendQuick(bookingId, meta.currentEpochId!,
          template.key, template.version, key, params: params);
      if (!mounted) return;
      await refresh();
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
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
