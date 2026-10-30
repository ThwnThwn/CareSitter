import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/support_chat/data/models/support_conversation_model.dart';

class SupportChatLabels {
  const SupportChatLabels._();

  static String status(SupportConversation? conversation) {
    if (conversation == null) return 'Gửi yêu cầu hỗ trợ';
    if (conversation.isClosed) return 'Hội thoại đã kết thúc';
    return conversation.status == 'NEW'
        ? 'Đang chờ tiếp nhận'
        : 'Đang xử lý yêu cầu';
  }

  static String day(DateTime value, {DateTime? now}) {
    final date = value.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = DateTime(current.year, current.month, current.day - 1);
    final messageDay = DateTime(date.year, date.month, date.day);
    if (messageDay == today) return 'Hôm nay';
    if (messageDay == yesterday) return 'Hôm qua';
    return formatDate(date, padded: true);
  }
}
