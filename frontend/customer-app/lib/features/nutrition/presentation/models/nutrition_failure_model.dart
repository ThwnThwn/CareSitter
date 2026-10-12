import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../domain/nutrition_response_rules.dart';

class NutritionFailureModel {
  NutritionFailureModel(this.error);
  final Object error;
  bool get denied =>
      error is AppApiException &&
      NutritionResponseRules.denied((error as AppApiException).statusCode);
  bool get stale =>
      error is AppApiException &&
      NutritionResponseRules.stale((error as AppApiException).statusCode,
          (error as AppApiException).code);
  String get message {
    final value = error;
    if (value is AppApiException) {
      if (value.statusCode == 404) {
        return 'Hồ sơ hoặc nội dung không còn khả dụng.';
      }
      final detail = value.details?['detail'];
      return detail is String
          ? detail
          : 'Chưa kết nối được dịch vụ. Dữ liệu đã nhập vẫn được giữ.';
    }
    return value is StateError
        ? value.message.toString()
        : 'Chưa xử lý được yêu cầu. Vui lòng thử lại.';
  }
}
