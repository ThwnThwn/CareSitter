import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_conversation_model.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_message_model.dart';
import 'package:caresitter_customer/features/support_chat/data/support_chat_repository.dart';
import 'package:caresitter_customer/features/support_chat/data/support_chat_realtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final supportChatControllerProvider =
    StateNotifierProvider.autoDispose<SupportChatController, SupportChatState>(
        (ref) {
  ref.watch(authStateProvider.select((session) => session.valueOrNull?.userId));
  return SupportChatController(
      ref.read(supportChatRepositoryProvider), SupportChatRealtime(ref));
});

class SupportChatState {
  const SupportChatState(
      {this.loading = true,
      this.busy = false,
      this.enabled = false,
      this.error,
      this.conversation,
      this.messages = const []});
  final bool loading;
  final bool busy;
  final bool enabled;
  final String? error;
  final SupportConversation? conversation;
  final List<SupportMessage> messages;

  SupportChatState copyWith(
          {bool? loading,
          bool? busy,
          bool? enabled,
          String? error,
          bool clearError = false,
          SupportConversation? conversation,
          bool clearConversation = false,
          List<SupportMessage>? messages}) =>
      SupportChatState(
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        enabled: enabled ?? this.enabled,
        error: clearError ? null : error ?? this.error,
        conversation:
            clearConversation ? null : conversation ?? this.conversation,
        messages: messages ?? this.messages,
      );
}

class SupportChatController extends StateNotifier<SupportChatState> {
  SupportChatController(this._repository, [this._realtime])
      : super(const SupportChatState()) {
    _realtimeSubscription =
        _realtime?.changes.listen((_) => unawaited(refresh()));
    unawaited(refresh());
    _startTimer();
  }

  final SupportChatRepository _repository;
  final SupportChatRealtime? _realtime;
  StreamSubscription<void>? _realtimeSubscription;
  Timer? _timer;
  Future<void>? _refreshTask;
  String? _createKey;
  String? _createPayload;
  String? _sendKey;
  String? _sendPayload;
  bool _active = true;
  String? _lastReadConversationId;
  int _lastReadRequested = 0;

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
      if (_realtime != null) unawaited(_realtime!.disconnect());
    }
  }

  Future<void> refresh() => !_active
      ? Future<void>.value()
      : _refreshTask ??= _reload().whenComplete(() {
          _refreshTask = null;
        });

  Future<void> _reload() async {
    try {
      final enabled = await _repository.isEnabled();
      if (!mounted) return;
      if (!enabled) {
        unawaited(_realtime?.disconnect());
        state =
            state.copyWith(enabled: false, loading: false, clearError: true);
        return;
      }
      final conversations = await _repository.conversations();
      if (!mounted) return;
      final open = conversations.where((item) => !item.isClosed).firstOrNull;
      final current = state.conversation;
      final target = open ?? current ?? conversations.firstOrNull;
      if (target == null) {
        unawaited(_realtime?.disconnect());
        state = state.copyWith(
            enabled: true,
            loading: false,
            clearConversation: true,
            messages: const [],
            clearError: true);
        return;
      }
      final detail = await _repository.get(target.id);
      final same = current?.id == target.id;
      final incoming = <SupportMessage>[];
      var after =
          same && state.messages.isNotEmpty ? state.messages.last.sequence : 0;
      int? watermark;
      // A fixed watermark makes every multi-page recovery deterministic.
      for (var pageIndex = 0; pageIndex < 1000; pageIndex++) {
        final page = await _repository.messages(target.id, after, watermark);
        watermark ??= page.highWatermarkSequence;
        incoming.addAll(page.items);
        after = page.nextAfterSequence ?? after;
        if (!page.hasMore) break;
      }
      if (!mounted) return;
      final bySequence = <int, SupportMessage>{
        if (same)
          for (final message in state.messages) message.sequence: message,
        for (final message in incoming) message.sequence: message,
      };
      final sorted = bySequence.values.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      state = state.copyWith(
          enabled: true,
          loading: false,
          conversation: detail,
          messages: sorted,
          clearError: true);
      if (_realtime != null && _active) {
        unawaited(_realtime!.connect(detail.id));
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(loading: false, error: error.toString());
      }
    }
  }

  Future<void> markVisibleRead() async {
    final conversation = state.conversation;
    if (!_active || conversation == null || state.messages.isEmpty) return;
    final visibleSequence = state.messages.last.sequence;
    if (_lastReadConversationId != conversation.id) {
      _lastReadConversationId = conversation.id;
      _lastReadRequested = conversation.ownLastReadSequence;
    }
    if (visibleSequence <= _lastReadRequested) return;
    _lastReadRequested = visibleSequence;
    try {
      await _repository.read(conversation.id, visibleSequence);
    } catch (_) {
      if (_lastReadConversationId == conversation.id) _lastReadRequested = 0;
    }
  }

  Future<void> create(String subject, String firstMessage) async {
    if (state.busy || !state.enabled) return;
    final cleanSubject = subject.trim();
    final cleanMessage = firstMessage.trim();
    final payload = '$cleanSubject\n$cleanMessage';
    if (cleanSubject.length < 3 || cleanMessage.length < 10) {
      state =
          state.copyWith(error: 'Nhập tiêu đề và nội dung ít nhất 10 ký tự.');
      return;
    }
    if (_createPayload != payload) {
      _createPayload = payload;
      _createKey = const Uuid().v4();
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final conversation =
          await _repository.create(cleanSubject, cleanMessage, _createKey!);
      if (!mounted) return;
      _createKey = null;
      _createPayload = null;
      state = state.copyWith(conversation: conversation, messages: const []);
      await refresh();
    } catch (error) {
      if (mounted) state = state.copyWith(error: error.toString());
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> send(String body) async {
    final conversation = state.conversation;
    final clean = body.trim();
    if (conversation == null ||
        conversation.isClosed ||
        state.busy ||
        clean.isEmpty) {
      return;
    }
    if (_sendPayload != clean) {
      _sendPayload = clean;
      _sendKey = const Uuid().v4();
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repository.send(conversation.id, clean, _sendKey!);
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

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    _realtime?.dispose();
    super.dispose();
  }
}
