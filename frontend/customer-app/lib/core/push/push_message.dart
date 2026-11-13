class PushMessage {
  const PushMessage(
      {required this.id,
      required this.data,
      required this.sentAt,
      this.title = 'CareSitter',
      this.body = ''});
  final String id, title, body;
  final Map<String, dynamic> data;
  final DateTime sentAt;
}
