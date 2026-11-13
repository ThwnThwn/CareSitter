import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/report_document.dart';

final reportDraftStoreProvider =
    Provider<ReportDraftStore>((_) => ReportDraftStore());

/// The same encrypted bytes/key survive navigation, restart and unknown upload outcomes.
class ReportDraftStore {
  static const _storage = FlutterSecureStorage();
  String _key(String owner, String booking) =>
      'report_draft_${sha256.convert(utf8.encode('$owner:$booking'))}';
  Future<ReportDocument?> load(String owner, String booking) async {
    final raw = await _storage.read(key: _key(owner, booking));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ReportDocument(
        bytes: Uint8List.fromList(base64Decode(json['bytes'] as String)),
        idempotencyKey: json['key'] as String,
        attempted: json['attempted'] == true,
        completedId: json['completedId'] as String?);
  }

  Future<void> save(String owner, String booking, ReportDocument document) =>
      _storage.write(
          key: _key(owner, booking),
          value: jsonEncode({
            'key': document.idempotencyKey,
            'bytes': base64Encode(document.bytes),
            'attempted': document.attempted,
            'completedId': document.completedId
          }));
  Future<void> remove(String owner, String booking) =>
      _storage.delete(key: _key(owner, booking));
}
