import 'package:caregiver_app/core/api/dio_client.dart';
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
  (ref) => BookingChatRepository(ref.read(dioClientProvider)),
);

class BookingChatRepository implements BookingChatRepositoryPort {
  const BookingChatRepository(this._client);

  final DioClient _client;

  @override
  Future<BookingChatMeta> metadata(String bookingId) async {
    final response = await _client
        .get<Map<String, dynamic>>('/api/v1/bookings/$bookingId/chat');
    return BookingChatMeta.fromJson(response.data!);
  }

  @override
  Future<BookingChatPage> messages(
    String bookingId, {
    String? afterCursor,
    String? beforeCursor,
    int limit = 50,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/v1/bookings/$bookingId/chat/messages',
      query: {
        if (afterCursor != null) 'afterCursor': afterCursor,
        if (beforeCursor != null) 'beforeCursor': beforeCursor,
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
      '/api/v1/bookings/$bookingId/chat/messages',
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
      '/api/v1/bookings/$bookingId/chat/messages',
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
        '/api/v1/bookings/$bookingId/chat/read',
        data: {
          'epochId': epochId,
          'lastReadMessageId': lastReadMessageId,
        },
      ).then((_) {});
}

String _requiredResponseId(Map<String, dynamic>? data) {
  final id = data?['id']?.toString().trim();
  if (id == null || id.isEmpty) {
    throw const FormatException('Booking Chat send response is missing id.');
  }
  return id;
}
