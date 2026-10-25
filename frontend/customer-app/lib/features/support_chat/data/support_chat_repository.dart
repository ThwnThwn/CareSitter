import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_conversation_model.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_message_model.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_message_page_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportChatRepositoryProvider = Provider<SupportChatRepository>(
  (ref) => SupportChatRepository(ref.read(dioClientProvider)),
);

class SupportChatRepository {
  const SupportChatRepository(this._client);
  final DioClient _client;

  Future<bool> isEnabled() async {
    final response =
        await _client.get<Map<String, dynamic>>('/support/chat-config');
    return response.data?['enabled'] == true;
  }

  Future<List<SupportConversation>> conversations() async {
    final response = await _client.get<Map<String, dynamic>>(
        '/support/conversations',
        query: {'limit': 50});
    final items = response.data?['items'];
    return (items is List ? items : const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportConversation.fromJson)
        .toList(growable: false);
  }

  Future<SupportConversation> get(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/support/conversations/$id');
    return SupportConversation.fromJson(response.data!);
  }

  Future<SupportConversation> create(
      String subject, String body, String key) async {
    final response = await _client.postIdempotent<Map<String, dynamic>>(
        '/support/conversations',
        idempotencyKey: key,
        data: {'subject': subject, 'firstMessage': body});
    return SupportConversation.fromJson(
        Map<String, dynamic>.from(response.data!['conversation'] as Map));
  }

  Future<SupportMessagePage> messages(
      String id, int after, int? watermark) async {
    final response = await _client.get<Map<String, dynamic>>(
        '/support/conversations/$id/messages',
        query: {
          'afterSequence': after,
          'limit': 100,
          if (watermark != null) 'highWatermarkSequence': watermark,
        });
    final json = response.data!;
    final items = json['items'];
    return SupportMessagePage(
      (items is List ? items : const [])
          .whereType<Map<String, dynamic>>()
          .map(SupportMessage.fromJson)
          .toList(growable: false),
      json['hasMore'] == true,
      (json['nextAfterSequence'] as num?)?.toInt(),
      (json['highWatermarkSequence'] as num?)?.toInt() ?? after,
    );
  }

  Future<void> send(String id, String body, String key) =>
      _client.postIdempotent<Map<String, dynamic>>(
          '/support/conversations/$id/messages',
          idempotencyKey: key,
          data: {'body': body}).then((_) {});

  Future<void> read(String id, int sequence) =>
      _client.put<Map<String, dynamic>>('/support/conversations/$id/read',
          data: {'lastReadSequence': sequence}).then((_) {});
}
