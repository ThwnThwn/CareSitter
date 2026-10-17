import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final bookingChatRepositoryProvider = Provider<BookingChatRepository>(
  (ref) => BookingChatRepository(ref.read(dioClientProvider)),
);

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class BookingChatTemplate {
  const BookingChatTemplate(
      {required this.key, required this.version, required this.body,
       this.allowedMinutes});
  final String key;
  final int version;
  final String body;
  final List<int>? allowedMinutes;
}

class BookingChatMeta {
  const BookingChatMeta({
    required this.featureEnabled,
    required this.bookingId,
    this.conversationId,
    this.currentEpochId,
    required this.state,
    required this.canRead,
    required this.canSend,
    required this.readOnlyReason,
    required this.serverNow,
    this.writeClosesAt,
    required this.lastReadSequence,
    required this.otherPartyLastReadSequence,
    required this.unreadCount,
    required this.changeVersion,
    required this.scopeVersion,
    required this.quickTemplates,
  });

  final bool featureEnabled;
  final String bookingId;
  final String? conversationId;
  final String? currentEpochId;
  final String state;
  final bool canRead;
  final bool canSend;
  final String readOnlyReason;
  final DateTime serverNow;
  final DateTime? writeClosesAt;
  final int lastReadSequence;
  final int otherPartyLastReadSequence;
  final int unreadCount;
  final int changeVersion;
  final int scopeVersion;
  final List<BookingChatTemplate> quickTemplates;

  bool get isOpen => state == 'open' || state == 'post_shift_grace';
  bool get isReadOnly => !canSend;
  bool get hasChat => conversationId != null;

  factory BookingChatMeta.fromJson(Map<String, dynamic> json) =>
      BookingChatMeta(
        featureEnabled: json['featureEnabled'] == true,
        bookingId: json['bookingId']?.toString() ?? '',
        conversationId: json['conversationId']?.toString(),
        currentEpochId: json['currentEpochId']?.toString(),
        state: json['state']?.toString() ?? 'unavailable',
        canRead: json['canRead'] == true,
        canSend: json['canSend'] == true,
        readOnlyReason: json['readOnlyReason']?.toString() ?? '',
        serverNow: DateTime.tryParse(json['serverNow']?.toString() ?? '') ??
            DateTime.now(),
        writeClosesAt:
            DateTime.tryParse(json['writeClosesAt']?.toString() ?? ''),
        lastReadSequence: (json['lastReadSequence'] as num?)?.toInt() ?? 0,
        otherPartyLastReadSequence:
            (json['otherPartyLastReadSequence'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        changeVersion: (json['changeVersion'] as num?)?.toInt() ?? 0,
        scopeVersion: (json['scopeVersion'] as num?)?.toInt() ?? 0,
        quickTemplates: _parseTemplates(json['quickTemplates']),
      );

  static List<BookingChatTemplate> _parseTemplates(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((t) => BookingChatTemplate(
              key: t['key']?.toString() ?? '',
              version: (t['version'] as num?)?.toInt() ?? 1,
              body: t['body']?.toString() ?? '',
              allowedMinutes: (t['allowedMinutes'] as List?)
                  ?.whereType<num>()
                  .map((n) => n.toInt())
                  .toList(),
            ))
        .toList(growable: false);
  }
}

class BookingChatMessage {
  const BookingChatMessage({
    required this.id,
    required this.epochId,
    required this.sequence,
    this.senderRole,
    required this.kind,
    this.templateKey,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String epochId;
  final int sequence;
  final String? senderRole;
  final String kind;
  final String? templateKey;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  bool get isSystem => kind == 'system';

  factory BookingChatMessage.fromJson(Map<String, dynamic> json) =>
      BookingChatMessage(
        id: json['id']?.toString() ?? '',
        epochId: json['epochId']?.toString() ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        senderRole: json['senderRole']?.toString(),
        kind: json['kind']?.toString() ?? 'text',
        templateKey: json['templateKey']?.toString(),
        body: json['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.now(),
        isMine: json['isMine'] == true,
      );
}

class BookingChatPage {
  const BookingChatPage(this.items, this.hasMoreBefore, this.hasMoreAfter,
      this.nextCursor, this.previousCursor, this.highWatermark,
      this.scopeVersion);
  final List<BookingChatMessage> items;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final String? nextCursor;
  final String? previousCursor;
  final int highWatermark;
  final int scopeVersion;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class BookingChatRepository {
  const BookingChatRepository(this._client);
  final DioClient _client;

  Future<BookingChatMeta> metadata(String bookingId) async {
    final response = await _client
        .get<Map<String, dynamic>>('/api/v1/bookings/$bookingId/chat');
    return BookingChatMeta.fromJson(response.data!);
  }

  Future<BookingChatPage> messages(String bookingId,
      {String? afterCursor, String? beforeCursor, int limit = 50}) async {
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

  Future<String> sendText(String bookingId, String epochId, String text,
      String idempotencyKey) async {
    final response = await _client.postIdempotent<Map<String, dynamic>>(
      '/api/v1/bookings/$bookingId/chat/messages',
      idempotencyKey: idempotencyKey,
      data: {
        'expectedEpochId': epochId,
        'kind': 'text',
        'text': text,
      },
    );
    return response.data?['id']?.toString() ?? const Uuid().v4();
  }

  Future<String> sendQuick(String bookingId, String epochId,
      String templateKey, int templateVersion, String idempotencyKey,
      {Map<String, String>? params}) async {
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
    return response.data?['id']?.toString() ?? const Uuid().v4();
  }

  Future<void> markRead(
      String bookingId, String epochId, String lastReadMessageId) =>
      _client
          .put<Map<String, dynamic>>(
            '/api/v1/bookings/$bookingId/chat/read',
            data: {
              'epochId': epochId,
              'lastReadMessageId': lastReadMessageId,
            },
          )
          .then((_) {});
}
