import 'dart:async';

import 'package:caregiver_app/features/booking_chat/data/booking_chat_realtime.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/booking_chat/presentation/booking_chat_controller.dart';
import 'package:caregiver_app/features/booking_chat/presentation/booking_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick suggestion has room for larger text', (tester) async {
    final repository = _FakeRepository()
      ..meta = _meta(quickTemplates: const [
        BookingChatTemplate(
            key: 'caregiver.arrived', version: 1, body: 'Tôi đã đến nơi'),
      ]);
    final controller = BookingChatController(
      bookingId: 'booking',
      repository: repository,
      realtime: _FakeRealtime(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookingChatControllerProvider
            .overrideWith((ref, bookingId) => controller),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: BookingChatScreen(bookingId: 'booking'),
        ),
      ),
    ));
    await tester.pump();

    final label = find.text('Tôi đã đến nơi');
    final chip = find.ancestor(
        of: label, matching: find.byType(GestureDetector));
    expect(chip, findsOneWidget);
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
    expect(tester.getRect(chip).contains(tester.getRect(label).bottomRight),
        isTrue);
  });

  testWidgets('clears the draft when read access is revoked', (tester) async {
    final repository = _FakeRepository();
    final controller = BookingChatController(
      bookingId: 'booking',
      repository: repository,
      realtime: _FakeRealtime(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookingChatControllerProvider
            .overrideWith((ref, bookingId) => controller),
      ],
      child: const MaterialApp(
        home: BookingChatScreen(bookingId: 'booking'),
      ),
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'nội dung riêng tư');

    repository.meta = _meta(canRead: false, canSend: false);
    await controller.refresh();
    await tester.pump();
    repository.meta = _meta(scopeVersion: 2);
    await controller.refresh();
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
  });
}

BookingChatMeta _meta({
  bool canRead = true,
  bool canSend = true,
  int scopeVersion = 1,
  List<BookingChatTemplate> quickTemplates = const [],
}) =>
    BookingChatMeta(
      featureEnabled: true,
      bookingId: 'booking',
      conversationId: 'conversation',
      currentEpochId: 'epoch',
      state: 'open',
      canRead: canRead,
      canSend: canSend,
      readOnlyReason: '',
      serverNow: DateTime.utc(2026),
      lastReadSequence: 0,
      otherPartyLastReadSequence: 0,
      unreadCount: 0,
      changeVersion: 1,
      scopeVersion: scopeVersion,
      quickTemplates: quickTemplates,
    );

class _FakeRepository implements BookingChatRepositoryPort {
  BookingChatMeta meta = _meta();

  @override
  Future<BookingChatMeta> metadata(String bookingId) async => meta;

  @override
  Future<BookingChatPage> messages(String bookingId,
          {String? afterCursor, String? beforeCursor, int limit = 50}) async =>
      const BookingChatPage([], false, false, null, null, 0, 1);

  @override
  Future<void> markRead(
      String bookingId, String epochId, String lastReadMessageId) async {}

  @override
  Future<void> reportMessage(
      String bookingId, String messageId, String reason) async {}

  @override
  Future<void> setBlocked(String bookingId, bool blocked) async {}

  @override
  Future<String> sendQuick(String bookingId, String epochId, String templateKey,
          int templateVersion, String idempotencyKey,
          {Map<String, String>? params}) async =>
      'quick';

  @override
  Future<String> sendText(String bookingId, String epochId, String text,
          String idempotencyKey) async =>
      'sent';
}

class _FakeRealtime implements BookingChatRealtimePort {
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> connect(String bookingId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    unawaited(_changes.close());
  }
}
