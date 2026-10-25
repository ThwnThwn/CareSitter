class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sequence,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

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
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
