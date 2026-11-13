class PushReceipt {
  const PushReceipt(
      {required this.id,
      required this.owner,
      required this.title,
      required this.body,
      required this.sentAt,
      required this.data,
      this.isRead = false});
  final String id, owner, title, body;
  final DateTime sentAt;
  final Map<String, dynamic> data;
  final bool isRead;
  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner,
        'title': title,
        'body': body,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'data': data
      };
  factory PushReceipt.fromJson(Map<String, dynamic> json,
          {bool isRead = false}) =>
      PushReceipt(
          id: json['id'] as String,
          owner: json['owner'] as String,
          title: json['title'] as String,
          body: json['body'] as String,
          sentAt: DateTime.parse(json['sentAt'] as String),
          data: Map<String, dynamic>.from(json['data'] as Map),
          isRead: isRead);
}
