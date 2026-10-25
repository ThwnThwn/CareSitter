import 'package:caresitter_customer/features/support_chat/data/models/support_message_model.dart';

class SupportMessagePage {
  const SupportMessagePage(
    this.items,
    this.hasMore,
    this.nextAfterSequence,
    this.highWatermarkSequence,
  );

  final List<SupportMessage> items;
  final bool hasMore;
  final int? nextAfterSequence;
  final int highWatermarkSequence;
}
