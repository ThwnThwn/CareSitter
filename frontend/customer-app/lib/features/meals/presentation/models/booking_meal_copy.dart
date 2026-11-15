import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';

String mealDateLabel(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : formatDate(date, padded: true);
}

String mealTypeLabel(String type) => switch (type) {
      'breakfast' => 'Bữa sáng',
      'lunch' => 'Bữa trưa',
      'dinner' => 'Bữa tối',
      _ => 'Bữa ăn',
    };

String mealOutcomeLabel(String outcome) => switch (outcome) {
      'eaten' => 'Đã ăn',
      'partly_eaten' => 'Ăn một phần',
      'not_eaten' => 'Không ăn',
      _ => 'Đã ghi nhận',
    };

String mealLoadError(Object error) => switch (error) {
      AppApiException(statusCode: 401) => 'Vui lòng đăng nhập lại.',
      AppApiException(statusCode: 403) =>
        'Bạn không có quyền xem bữa ăn của ca này.',
      AppApiException(statusCode: 404) =>
        'Không tìm thấy thông tin bữa ăn. Hãy tải lại.',
      AppApiException(statusCode: 400 || 409, :final message) => message,
      _ => 'Chưa tải được kết quả. Hãy thử lại.',
    };
