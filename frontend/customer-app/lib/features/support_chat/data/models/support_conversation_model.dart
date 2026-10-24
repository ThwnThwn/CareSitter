class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.subject,
    required this.status,
    required this.lastSequence,
    required this.ownLastReadSequence,
  });

  final String id;
  final String subject;
  final String status;
  final int lastSequence;
  final int ownLastReadSequence;

  factory SupportConversation.fromJson(Map<String, dynamic> json) =>
      SupportConversation(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? '',
        status: json['status'] as String? ?? 'NEW',
        lastSequence: (json['lastSequence'] as num?)?.toInt() ?? 0,
        ownLastReadSequence:
            (json['ownLastReadSequence'] as num?)?.toInt() ?? 0,
      );

  bool get isClosed => status == 'RESOLVED' || status == 'CLOSED';
}
