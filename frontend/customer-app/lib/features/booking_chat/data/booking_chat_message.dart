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
        id: _requiredText(json, 'id'),
        epochId: _requiredText(json, 'epochId'),
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        senderRole: json['senderRole']?.toString(),
        kind: json['kind']?.toString() ?? 'text',
        templateKey: json['templateKey']?.toString(),
        body: json['body']?.toString() ?? '',
        createdAt: _requiredDateTime(json, 'createdAt'),
        isMine: json['isMine'] == true,
      );
}

String _requiredText(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Booking Chat response is missing $key.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '');
  if (value == null) {
    throw FormatException('Booking Chat response has an invalid $key.');
  }
  return value;
}
