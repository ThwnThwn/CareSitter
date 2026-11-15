import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';

const mealOutcomeLabels = {
  'eaten': 'Đã ăn',
  'partly_eaten': 'Ăn một phần',
  'not_eaten': 'Không ăn',
};

String mealTypeLabel(String type) => switch (type) {
      'breakfast' => 'Bữa sáng',
      'lunch' => 'Bữa trưa',
      'dinner' => 'Bữa tối',
      _ => 'Bữa ăn',
    };

String mealDateLabel(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : formatDate(date, padded: true);
}

String mealApiError(Object? error) => switch (error) {
      AppApiException(statusCode: 401) => 'Vui lòng đăng nhập lại.',
      AppApiException(statusCode: 403) =>
        'Bạn không còn quyền thao tác với bữa ăn của ca này.',
      AppApiException(statusCode: 400 || 409, :final message) => message,
      _ => 'Chưa lấy được kết quả. Hãy thử lại.',
    };
