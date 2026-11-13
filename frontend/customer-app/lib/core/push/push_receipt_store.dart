import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_message.dart';
import 'push_receipt.dart';
import 'push_receipt_storage.dart';

final pushReceiptStoreProvider =
    Provider((_) => PushReceiptStore(SecurePushReceiptStorage()));

/// One encrypted key per delivery: background and main isolates never overwrite an inbox list.
class PushReceiptStore {
  PushReceiptStore(this.storage);
  final PushReceiptStorage storage;
  static const _binding = 'push_receipt_bound_owner';
  Future<void> _bindingWrites = Future.value();
  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
  String _prefix(String owner) => 'push_receipt_${_hash(owner)}_';
  String _key(String owner, String id) => '${_prefix(owner)}${_hash(id)}';
  // A logout delete must follow an already-started secure-storage write.
  Future<void> _updateBinding(Future<void> Function() action) {
    final next = _bindingWrites.then((_) => action());
    _bindingWrites =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> bind(String owner) =>
      _updateBinding(() => storage.write(_binding, owner));
  Future<void> clearBinding() => _updateBinding(() => storage.delete(_binding));

  Future<bool> capture(PushMessage message) async {
    // Console tests are explicitly addressed. Unaddressed pushes cannot be attributed after logout/account switch.
    final owner = await storage.read(_binding);
    if (owner == null ||
        message.data['source'] != 'console_test' ||
        message.data['recipient_user_id'] != owner ||
        message.id.isEmpty ||
        message.sentAt.isBefore(
            DateTime.now().toUtc().subtract(const Duration(days: 30)))) {
      return false;
    }
    final data = <String, dynamic>{};
    for (final key in ['type', 'bookingId', 'deepLink', 'status']) {
      final value = message.data[key];
      if (value is String && value.length <= 256) data[key] = value;
    }
    final receipt = PushReceipt(
        id: 'console:${message.id}',
        owner: owner,
        title: message.title.substring(0, message.title.length.clamp(0, 256)),
        body: message.body.substring(0, message.body.length.clamp(0, 1024)),
        sentAt: message.sentAt,
        data: data);
    if (await storage.read(_binding) != owner) return false;
    await storage.write(_key(owner, receipt.id), jsonEncode(receipt.toJson()));
    await _prune(owner);
    return true;
  }

  Future<List<PushReceipt>> list(String owner) async {
    Map<String, String> values;
    try {
      values = await storage.readAll();
    } catch (_) {
      return const [];
    }
    final items = <PushReceipt>[];
    for (final entry
        in values.entries.where((e) => e.key.startsWith(_prefix(owner)))) {
      try {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        final id = json['id'] as String;
        final receipt = PushReceipt.fromJson(json,
            isRead: values['push_read_${_hash(owner)}_${_hash(id)}'] == '1');
        if (receipt.owner == owner &&
            receipt.sentAt.isAfter(
                DateTime.now().toUtc().subtract(const Duration(days: 30)))) {
          items.add(receipt);
        }
      } catch (_) {/* Corrupt single receipt cannot hide the server inbox. */}
    }
    items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return items.take(100).toList();
  }

  Future<void> markRead(String owner, String id) =>
      storage.write('push_read_${_hash(owner)}_${_hash(id)}', '1');
  Future<void> _prune(String owner) async {
    final values = await storage.readAll();
    final records = <({String key, DateTime time, String id})>[];
    for (final e
        in values.entries.where((e) => e.key.startsWith(_prefix(owner)))) {
      try {
        final value = jsonDecode(e.value) as Map<String, dynamic>;
        records.add((
          key: e.key,
          time: DateTime.parse(value['sentAt'] as String),
          id: value['id'] as String
        ));
      } catch (_) {
        await storage.delete(e.key);
      }
    }
    records.sort((a, b) => b.time.compareTo(a.time));
    for (var i = 0; i < records.length; i++) {
      if (i >= 100 ||
          records[i].time.isBefore(
              DateTime.now().toUtc().subtract(const Duration(days: 30)))) {
        await storage.delete(records[i].key);
        await storage
            .delete('push_read_${_hash(owner)}_${_hash(records[i].id)}');
      }
    }
  }
}
