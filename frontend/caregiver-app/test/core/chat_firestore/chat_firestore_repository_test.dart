import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/chat_firestore/chat_firestore_reader.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:caregiver_app/features/support_chat/data/support_chat_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Http implements DioClient {
  String? path;
  Map<String, dynamic>? query;
  Map<String, dynamic> payload = {};

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? query, CancelToken? cancelToken}) async {
    this.path = path;
    this.query = query;
    return Response<T>(
        data: payload as T,
        requestOptions: RequestOptions(path: path),
        statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Reader extends ChatFirestoreReader {
  _Reader(DioClient client) : super(client, () => 'owner');
  bool unavailable = false;
  int? maximum;
  ChatFirestoreBatch batch = const ChatFirestoreBatch([], false, 0);

  @override
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
    maximum = maxSequence;
    if (unavailable) throw StateError('Projection is unavailable.');
    return batch;
  }
}

Map<String, dynamic> message(int sequence) => {
      'id': 'message-$sequence',
      'epochId': 'epoch',
      'sequence': sequence,
      'kind': 'text',
      'body': 'test',
      'senderRole': 'CUSTOMER',
      'createdAt': '2026-10-28T00:00:00Z',
      'isMine': true,
    };

void main() {
  for (final direction in ['after', 'before']) {
    test(
        'booking resumes the $direction anchor through API after Firestore fails',
        () async {
      final http = _Http()
        ..payload = {
          'bookingId': 'booking',
          'conversationId': 'conversation',
          'currentEpochId': 'epoch',
          'scopeVersion': 1,
          'changeVersion': 3,
          'canRead': true,
          'featureEnabled': true,
          'serverNow': '2026-10-28T00:00:00Z',
        };
      final reader = _Reader(http)
        ..batch = ChatFirestoreBatch([message(75)], true, 125);
      final repository = BookingChatRepository(http, reader);
      await repository.metadata('booking');
      final first = await repository.messages('booking');
      final cursor =
          direction == 'after' ? first.nextCursor! : first.previousCursor!;
      reader.unavailable = true;
      http.payload = {
        'items': [message(direction == 'after' ? 76 : 74)],
        'nextCursor': 'protected-next',
        'previousCursor': 'protected-before',
        'scopeVersion': 1,
        'highWatermark': 125,
      };

      final fallback = await repository.messages('booking',
          afterCursor: direction == 'after' ? cursor : null,
          beforeCursor: direction == 'before' ? cursor : null);

      expect(http.path, '/bookings/booking/chat/messages/resume');
      expect(http.query, {
        'anchorMessageId': 'message-75',
        'scopeVersion': 1,
        'direction': direction,
        'limit': 50,
      });
      expect(fallback.nextCursor, 'protected-next');
      expect(fallback.items.single.sequence, direction == 'after' ? 76 : 74);
    });
  }

  test('support keeps the recovery watermark across Firestore and API fallback',
      () async {
    final http = _Http()..payload = {'id': 'support', 'lastSequence': 125};
    final reader = _Reader(http)
      ..batch = ChatFirestoreBatch([message(76)], false, 100);
    final repository = SupportChatRepository(http, reader);
    await repository.get('support');

    final projected = await repository.messages('support', 75, 100);
    expect(reader.maximum, 100);
    expect(projected.highWatermarkSequence, 100);

    reader.unavailable = true;
    http.payload = {'items': [], 'highWatermarkSequence': 100};
    final fallback = await repository.messages('support', 76, 100);
    expect(http.query, {
      'afterSequence': 76,
      'limit': 100,
      'highWatermarkSequence': 100,
    });
    expect(fallback.highWatermarkSequence, 100);
  });

  test('a repository without the pilot reader uses the existing API cursor',
      () async {
    final http = _Http()..payload = {'items': []};
    await BookingChatRepository(http)
        .messages('booking', afterCursor: 'protected-next');
    expect(http.path, '/bookings/booking/chat/messages');
    expect(http.query, {'afterCursor': 'protected-next', 'limit': 50});
  });
}
