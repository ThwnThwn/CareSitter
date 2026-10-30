import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/chat_firestore/chat_firestore_reader.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_message.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_meta.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_page.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository_port.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:caregiver_app/features/booking_chat/data/booking_chat_message.dart';
export 'package:caregiver_app/features/booking_chat/data/booking_chat_meta.dart';
export 'package:caregiver_app/features/booking_chat/data/booking_chat_page.dart';
export 'package:caregiver_app/features/booking_chat/data/booking_chat_repository_port.dart';
export 'package:caregiver_app/features/booking_chat/data/booking_chat_template.dart';

final bookingChatRepositoryProvider = Provider<BookingChatRepositoryPort>(
  (ref) => BookingChatRepository(
      ref.read(dioClientProvider), ref.read(chatFirestoreReaderProvider)),
);

class BookingChatRepository implements BookingChatRepositoryPort {
  BookingChatRepository(this._client, [this._firestore]);

  final DioClient _client;
  final ChatFirestoreReader? _firestore;
  BookingChatMeta? _meta;

  @override
  Future<BookingChatMeta> metadata(String bookingId) async {
    final response =
        await _client.get<Map<String, dynamic>>('/bookings/$bookingId/chat');
    return _meta = BookingChatMeta.fromJson(response.data!);
  }

  @override
  Future<BookingChatPage> messages(
    String bookingId, {
    String? afterCursor,
    String? beforeCursor,
    int limit = 50,
  }) async {
    final meta = _meta;
    if (_firestore != null &&
        meta?.bookingId == bookingId &&
        meta?.conversationId != null &&
        meta?.currentEpochId != null &&
        meta?.scopeVersion == 1 &&
        (afterCursor == null || afterCursor.startsWith('fs:')) &&
        (beforeCursor == null || beforeCursor.startsWith('fs:'))) {
      try {
        final after =
            afterCursor == null ? null : int.parse(afterCursor.split(':')[2]);
        final before =
            beforeCursor == null ? null : int.parse(beforeCursor.split(':')[2]);
        final batch = await _firestore!.messages(
          type: 'BOOKING',
          conversationId: meta!.conversationId!,
          epochId: meta.currentEpochId!,
          afterSequence: after,
          beforeSequence: before,
          expectedVersion: meta.changeVersion,
          limit: limit,
        );
        final items = batch.items
            .map(BookingChatMessage.fromJson)
            .toList(growable: false);
        String cursor(BookingChatMessage message) =>
            'fs:${meta.scopeVersion}:${message.sequence}:${message.id}';
        final next = items.isEmpty ? afterCursor : cursor(items.last);
        return BookingChatPage(
            items,
            beforeCursor != null
                ? batch.hasMore
                : afterCursor == null && batch.hasMore,
            afterCursor != null && batch.hasMore,
            next,
            items.isEmpty ? beforeCursor : cursor(items.first),
            batch.highWatermark,
            meta.scopeVersion);
      } catch (_) {
        // Projection lag and Firebase outages fall back to PostgreSQL reads.
      }
    }
    final resume = (afterCursor ?? beforeCursor)?.startsWith('fs:') == true
        ? (afterCursor ?? beforeCursor)!.split(':')
        : null;
    final response = await _client.get<Map<String, dynamic>>(
      '/bookings/$bookingId/chat/messages${resume == null ? '' : '/resume'}',
      query: {
        if (resume != null) ...{
          'anchorMessageId': resume[3],
          'scopeVersion': int.parse(resume[1]),
          'direction': afterCursor != null ? 'after' : 'before',
        },
        if (afterCursor != null && !afterCursor.startsWith('fs:'))
          'afterCursor': afterCursor,
        if (beforeCursor != null && !beforeCursor.startsWith('fs:'))
          'beforeCursor': beforeCursor,
        'limit': limit,
      },
    );
    final json = response.data!;
    final items = json['items'];
    return BookingChatPage(
      (items is List ? items : const [])
          .whereType<Map<String, dynamic>>()
          .map(BookingChatMessage.fromJson)
          .toList(growable: false),
      json['hasMoreBefore'] == true,
      json['hasMoreAfter'] == true,
      json['nextCursor']?.toString(),
      json['previousCursor']?.toString(),
      (json['highWatermark'] as num?)?.toInt() ?? 0,
      (json['scopeVersion'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<String> sendText(
    String bookingId,
    String epochId,
    String text,
    String idempotencyKey,
  ) async {
    final response = await _client.postIdempotent<Map<String, dynamic>>(
      '/bookings/$bookingId/chat/messages',
      idempotencyKey: idempotencyKey,
      data: {
        'expectedEpochId': epochId,
        'kind': 'text',
        'text': text,
      },
    );
    return _requiredResponseId(response.data);
  }

  @override
  Future<String> sendQuick(
    String bookingId,
    String epochId,
    String templateKey,
    int templateVersion,
    String idempotencyKey, {
    Map<String, String>? params,
  }) async {
    final response = await _client.postIdempotent<Map<String, dynamic>>(
      '/bookings/$bookingId/chat/messages',
      idempotencyKey: idempotencyKey,
      data: {
        'expectedEpochId': epochId,
        'kind': 'quick_message',
        'templateKey': templateKey,
        'templateVersion': templateVersion,
        if (params != null) 'templateParams': params,
      },
    );
    return _requiredResponseId(response.data);
  }

  @override
  Future<void> markRead(
    String bookingId,
    String epochId,
    String lastReadMessageId,
  ) =>
      _client.put<Map<String, dynamic>>(
        '/bookings/$bookingId/chat/read',
        data: {
          'epochId': epochId,
          'lastReadMessageId': lastReadMessageId,
        },
      ).then((_) {});

  @override
  Future<void> reportMessage(
    String bookingId,
    String messageId,
    String reason,
  ) =>
      _client.post<Map<String, dynamic>>(
        '/bookings/$bookingId/chat/messages/$messageId/reports',
        data: {'reason': reason},
      ).then((_) {});

  @override
  Future<void> setBlocked(String bookingId, bool blocked) =>
      _client.put<Map<String, dynamic>>(
        '/bookings/$bookingId/chat/block',
        data: {'blocked': blocked},
      ).then((_) {});
}

String _requiredResponseId(Map<String, dynamic>? data) {
  final id = data?['id']?.toString().trim();
  if (id == null || id.isEmpty) {
    throw const FormatException('Booking Chat send response is missing id.');
  }
  return id;
}
