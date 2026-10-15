import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>(
  (ref) => SupportChatRepository(ref.read(dioClientProvider)),
);

class SupportConversation {
  const SupportConversation({required this.id, required this.subject,
    required this.status, required this.lastSequence, required this.ownLastReadSequence});
  final String id;
  final String subject;
  final String status;
  final int lastSequence;
  final int ownLastReadSequence;

  factory SupportConversation.fromJson(Map<String, dynamic> json) => SupportConversation(
    id: json['id'] as String,
    subject: json['subject'] as String? ?? '',
    status: json['status'] as String? ?? 'NEW',
    lastSequence: (json['lastSequence'] as num?)?.toInt() ?? 0,
    ownLastReadSequence: (json['ownLastReadSequence'] as num?)?.toInt() ?? 0,
  );

  bool get isClosed => status == 'RESOLVED' || status == 'CLOSED';
}

class SupportMessage {
  const SupportMessage({required this.id, required this.sequence,
    required this.senderRole, required this.body, required this.createdAt});
  final String id;
  final int sequence;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: json['id'] as String,
    sequence: (json['sequence'] as num).toInt(),
    senderRole: json['senderRole'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class SupportMessagePage {
  const SupportMessagePage(this.items, this.hasMore, this.nextAfterSequence,
    this.highWatermarkSequence);
  final List<SupportMessage> items;
  final bool hasMore;
  final int? nextAfterSequence;
  final int highWatermarkSequence;
}

class SupportChatRepository {
  const SupportChatRepository(this._client);
  final DioClient _client;

  Future<bool> isEnabled() async {
    final response = await _client.get<Map<String, dynamic>>('/support/chat-config');
    return response.data?['enabled'] == true;
  }

  Future<List<SupportConversation>> conversations() async {
    final response = await _client.get<Map<String, dynamic>>('/support/conversations',
      query: {'limit': 50});
    final items = response.data?['items'];
    return (items is List ? items : const [])
      .whereType<Map<String, dynamic>>()
      .map(SupportConversation.fromJson).toList(growable: false);
  }

  Future<SupportConversation> get(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/support/conversations/$id');
    return SupportConversation.fromJson(response.data!);
  }

  Future<SupportConversation> create(String subject, String body, String key) async {
    final response = await _client.postIdempotent<Map<String, dynamic>>(
      '/support/conversations', idempotencyKey: key,
      data: {'subject': subject, 'firstMessage': body});
    return SupportConversation.fromJson(
      Map<String, dynamic>.from(response.data!['conversation'] as Map));
  }

  Future<SupportMessagePage> messages(String id, int after, int? watermark) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/support/conversations/$id/messages', query: {
        'afterSequence': after, 'limit': 100,
        if (watermark != null) 'highWatermarkSequence': watermark,
      });
    final json = response.data!;
    final items = json['items'];
    return SupportMessagePage(
      (items is List ? items : const []).whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson).toList(growable: false),
      json['hasMore'] == true,
      (json['nextAfterSequence'] as num?)?.toInt(),
      (json['highWatermarkSequence'] as num?)?.toInt() ?? after,
    );
  }

  Future<void> send(String id, String body, String key) =>
    _client.postIdempotent<Map<String, dynamic>>(
      '/support/conversations/$id/messages', idempotencyKey: key,
      data: {'body': body}).then((_) {});

  Future<void> read(String id, int sequence) =>
    _client.put<Map<String, dynamic>>('/support/conversations/$id/read',
      data: {'lastReadSequence': sequence}).then((_) {});
}
