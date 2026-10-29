import 'dart:async';

import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_realtime.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads history, paginates, and marks the newest visible message read',
      () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('m2', 2)], hasMoreBefore: true, previous: 'older'),
        _page([_message('m1', 1)])
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();
    await controller.loadMore();
    expect(repository.beforeCursors, ['older']);
    expect(controller.state.messages.map((item) => item.sequence), [1, 2]);
    await controller.markVisibleRead();
    expect(repository.reads, [('booking', 'epoch', 'm2')]);
    controller.dispose();
  });

  test('keeps a failed send retryable and refreshes after SignalR reconnect',
      () async {
    final realtime = _FakeRealtime();
    final repository = _FakeRepository()..sendError = StateError('offline');
    final controller = BookingChatController(
        bookingId: 'booking', repository: repository, realtime: realtime);
    await _settle();
    await controller.sendText('xin chào');
    expect(controller.state.error, contains('offline'));
    repository.sendError = null;
    await controller.sendText('xin chào');
    realtime.events.add(null);
    await _settle();
    expect(repository.metadataCalls, greaterThanOrEqualTo(3));
    expect(realtime.connectCalls, isNotEmpty);
    controller.dispose();
  });

  test('loads every forward delta page so no message gap is permanent',
      () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('m50', 50)], next: 'cursor-50')
      ]
      ..afterPages = [
        _page([_message('m51', 51)], hasMoreAfter: true, next: 'cursor-51'),
        _page([_message('m52', 52)], next: 'cursor-52'),
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();

    await controller.refresh();

    expect(repository.afterCursors, ['cursor-50', 'cursor-51']);
    expect(controller.state.messages.map((message) => message.sequence),
        [50, 51, 52]);
    controller.dispose();
  });

  test('quick-message retry reuses the same idempotency key', () async {
    final repository = _FakeRepository()..sendError = StateError('offline');
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();
    const template =
        BookingChatTemplate(key: 'on_my_way', version: 1, body: 'Đang đến');

    await controller.sendQuick(template);
    repository.sendError = null;
    await controller.sendQuick(template);

    expect(repository.sentQuick, hasLength(2));
    expect(repository.sentQuick[1], repository.sentQuick[0]);
    controller.dispose();
  });

  test('does not send for an old caregiver/read-only epoch', () async {
    final repository = _FakeRepository()
      ..meta = _meta(canSend: false, state: 'read_only');
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();
    await controller.sendQuick(const BookingChatTemplate(
        key: 'on_my_way', version: 1, body: 'Đang đến'));
    expect(repository.sentQuick, isEmpty);
    controller.dispose();
  });

  test('clears cached messages when read access is revoked', () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('private-message', 1)],
            hasMoreBefore: true, previous: 'older')
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();

    repository.meta = _meta(canRead: false, canSend: false);
    await controller.refresh();

    expect(controller.state.canRead, isFalse);
    expect(controller.state.messages, isEmpty);
    expect(controller.state.previousCursor, isNull);
    expect(controller.state.hasMoreBefore, isFalse);
    controller.dispose();
  });

  test('does not merge messages across epoch changes', () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('old-epoch', 1)])
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();

    repository
      ..meta = _meta(epochId: 'epoch-2', scopeVersion: 2)
      ..pages = [
        _page([_message('new-epoch', 2, epochId: 'epoch-2')])
      ];
    await controller.refresh();

    expect(
        controller.state.messages.map((message) => message.id), ['new-epoch']);
    controller.dispose();
  });

  test('ignores an old loadMore response after the access scope changes',
      () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('old-latest', 2)],
            hasMoreBefore: true, previous: 'older')
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();

    final oldPage = Completer<BookingChatPage>();
    repository.pendingBeforePage = oldPage;
    final loadingOlderMessages = controller.loadMore();
    await _settle();

    repository
      ..meta = _meta(epochId: 'epoch-2', scopeVersion: 2)
      ..pages = [
        _page([_message('new-latest', 3, epochId: 'epoch-2')])
      ];
    await controller.refresh();
    oldPage.complete(_page([_message('old-history', 1)]));
    await loadingOlderMessages;

    expect(
        controller.state.messages.map((message) => message.id), ['new-latest']);
    expect(controller.state.busy, isFalse);
    controller.dispose();
  });

  for (final statusCode in [401, 403, 404]) {
    test('clears cached messages after a $statusCode metadata response',
        () async {
      final repository = _FakeRepository()
        ..pages = [
          _page([_message('private-message', 1)],
              hasMoreBefore: true, previous: 'older')
        ];
      final controller = BookingChatController(
          bookingId: 'booking',
          repository: repository,
          realtime: _FakeRealtime());
      await _settle();

      repository.metadataError =
          AppApiException(message: 'access denied', statusCode: statusCode);
      await controller.refresh();

      expect(controller.state.messages, isEmpty);
      expect(controller.state.previousCursor, isNull);
      expect(controller.state.meta, isNull);
      controller.dispose();
    });
  }

  test('clears cached messages after a refresh error', () async {
    final repository = _FakeRepository()
      ..pages = [
        _page([_message('private-message', 1)],
            hasMoreBefore: true, previous: 'older')
      ];
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();
    expect(controller.state.messages, isNotEmpty);

    repository.metadataError = StateError('offline');
    await controller.refresh();

    expect(controller.state.messages, isEmpty);
    expect(controller.state.previousCursor, isNull);
    expect(controller.state.meta, isNull);
    expect(controller.state.error, contains('offline'));
    controller.dispose();
  });

  test('updates the user block state through the repository', () async {
    final repository = _FakeRepository();
    final controller = BookingChatController(
        bookingId: 'booking',
        repository: repository,
        realtime: _FakeRealtime());
    await _settle();

    expect(await controller.setBlocked(true), isTrue);
    expect(repository.blockChanges, [('booking', true)]);
    controller.dispose();
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

BookingChatMeta _meta(
        {bool canRead = true,
        bool canSend = true,
        String epochId = 'epoch',
        int scopeVersion = 1,
        String state = 'open'}) =>
    BookingChatMeta(
      featureEnabled: true,
      bookingId: 'booking',
      conversationId: 'conversation',
      currentEpochId: epochId,
      state: state,
      canRead: canRead,
      canSend: canSend,
      readOnlyReason: '',
      serverNow: DateTime.utc(2026),
      lastReadSequence: 0,
      otherPartyLastReadSequence: 0,
      unreadCount: 0,
      changeVersion: 1,
      scopeVersion: scopeVersion,
      quickTemplates: const [],
    );

BookingChatMessage _message(String id, int sequence,
        {String epochId = 'epoch'}) =>
    BookingChatMessage(
      id: id,
      epochId: epochId,
      sequence: sequence,
      kind: 'text',
      body: 'message $sequence',
      createdAt: DateTime.utc(2026),
      isMine: false,
    );

BookingChatPage _page(List<BookingChatMessage> items,
        {bool hasMoreBefore = false,
        bool hasMoreAfter = false,
        String? next,
        String? previous}) =>
    BookingChatPage(items, hasMoreBefore, hasMoreAfter, next, previous,
        items.isEmpty ? 0 : items.last.sequence, 1);

class _FakeRepository implements BookingChatRepositoryPort {
  BookingChatMeta meta = _meta();
  List<BookingChatPage> pages = [
    _page([_message('m1', 1)])
  ];
  int metadataCalls = 0;
  Object? metadataError;
  final List<String?> beforeCursors = [];
  final List<(String, bool)> blockChanges = [];
  final List<String?> afterCursors = [];
  List<BookingChatPage> afterPages = [];
  final List<(String, String, String)> reads = [];
  final List<String> sentQuick = [];
  Object? sendError;
  Completer<BookingChatPage>? pendingBeforePage;
  @override
  Future<BookingChatMeta> metadata(String bookingId) async {
    metadataCalls++;
    if (metadataError != null) throw metadataError!;
    return meta;
  }

  @override
  Future<BookingChatPage> messages(String bookingId,
      {String? afterCursor, String? beforeCursor, int limit = 50}) async {
    if (afterCursor != null) {
      afterCursors.add(afterCursor);
      return afterPages.removeAt(0);
    }
    if (beforeCursor != null) {
      beforeCursors.add(beforeCursor);
      if (pendingBeforePage case final pending?) return pending.future;
    }
    return pages.length > 1 && beforeCursor != null
        ? pages.removeLast()
        : pages.first;
  }

  @override
  Future<void> markRead(
          String bookingId, String epochId, String lastReadMessageId) async =>
      reads.add((bookingId, epochId, lastReadMessageId));

  @override
  Future<void> reportMessage(
      String bookingId, String messageId, String reason) async {}

  @override
  Future<void> setBlocked(String bookingId, bool blocked) async =>
      blockChanges.add((bookingId, blocked));

  @override
  Future<String> sendText(String bookingId, String epochId, String text,
      String idempotencyKey) async {
    if (sendError != null) throw sendError!;
    return 'sent';
  }

  @override
  Future<String> sendQuick(String bookingId, String epochId, String templateKey,
      int templateVersion, String idempotencyKey,
      {Map<String, String>? params}) async {
    sentQuick.add(idempotencyKey);
    if (sendError != null) throw sendError!;
    return 'quick';
  }
}

class _FakeRealtime implements BookingChatRealtimePort {
  final events = StreamController<void>.broadcast();
  final List<String> connectCalls = [];
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<void> connect(String bookingId) async => connectCalls.add(bookingId);
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() {
    unawaited(events.close());
  }
}
