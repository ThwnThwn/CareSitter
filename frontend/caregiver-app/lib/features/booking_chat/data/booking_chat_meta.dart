import 'package:caregiver_app/features/booking_chat/data/booking_chat_template.dart';

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
        bookingId: _requiredMetaText(json, 'bookingId'),
        conversationId: json['conversationId']?.toString(),
        currentEpochId: json['currentEpochId']?.toString(),
        state: json['state']?.toString() ?? 'unavailable',
        canRead: json['canRead'] == true,
        canSend: json['canSend'] == true,
        readOnlyReason: json['readOnlyReason']?.toString() ?? '',
        serverNow: _requiredMetaDateTime(json, 'serverNow'),
        writeClosesAt: _optionalMetaDateTime(json, 'writeClosesAt'),
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
        .map((template) => BookingChatTemplate(
              key: template['key']?.toString() ?? '',
              version: (template['version'] as num?)?.toInt() ?? 1,
              body: template['body']?.toString() ?? '',
              allowedMinutes: (template['allowedMinutes'] as List?)
                  ?.whereType<num>()
                  .map((value) => value.toInt())
                  .toList(),
            ))
        .toList(growable: false);
  }
}

String _requiredMetaText(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Booking Chat metadata is missing $key.');
  }
  return value;
}

DateTime _requiredMetaDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '');
  if (value == null) {
    throw FormatException('Booking Chat metadata has an invalid $key.');
  }
  return value;
}

DateTime? _optionalMetaDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredMetaDateTime(json, key);
}
