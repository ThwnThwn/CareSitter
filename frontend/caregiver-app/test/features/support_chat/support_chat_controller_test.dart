import 'dart:io';

import 'package:caregiver_app/features/support_chat/data/support_chat_repository.dart';
import 'package:caregiver_app/features/support_chat/presentation/support_chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovers 125 dropped messages and retries with the same send key',
      () async {
    final repository = FakeSupportChatRepository();
    final controller = SupportChatController(repository);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.messages.length, 125);
    expect(controller.state.messages.first.sequence, 1);
    expect(controller.state.messages.last.sequence, 125);
    await controller.markVisibleRead();
    expect(repository.lastRead, 125);

    await controller.send('Xin hỗ trợ thêm');
    expect(controller.state.error, isNotNull);
    await controller.send('Xin hỗ trợ thêm');
    expect(repository.sentKeys.length, 2);
    expect(repository.sentKeys[0], repository.sentKeys[1]);
    expect(controller.state.error, isNull);
  });
}

class FakeSupportChatRepository implements SupportChatRepository {
  final conversation = const SupportConversation(
      id: 'conversation',
      subject: 'Hỗ trợ',
      status: 'IN_PROGRESS',
      lastSequence: 125,
      ownLastReadSequence: 0);
  final sentKeys = <String>[];
  int lastRead = 0;

  @override
  Future<bool> isEnabled() async => true;
  @override
  Future<List<SupportConversation>> conversations() async => [conversation];
  @override
  Future<SupportConversation> get(String id) async => conversation;
  @override
  Future<SupportMessagePage> messages(
      String id, int after, int? watermark) async {
    final end = (after + 100).clamp(0, 125);
    final items = [
      for (var sequence = after + 1; sequence <= end; sequence++)
        SupportMessage(
            id: '$sequence',
            sequence: sequence,
            senderRole: 'ADMIN',
            body: 'Tin $sequence',
            createdAt: DateTime.utc(2026))
    ];
    return SupportMessagePage(items, end < 125, end, 125);
  }

  @override
  Future<void> read(String id, int sequence) async {
    lastRead = sequence;
  }

  @override
  Future<void> send(String id, String body, String key) async {
    sentKeys.add(key);
    if (sentKeys.length == 1) throw const SocketException('Response lost');
  }

  @override
  Future<SupportConversation> create(
          String subject, String body, String key) async =>
      conversation;
}
