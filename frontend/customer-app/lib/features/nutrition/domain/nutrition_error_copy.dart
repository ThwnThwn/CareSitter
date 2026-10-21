import 'nutrition_error_codes.dart';

class NutritionErrorCopy {
  const NutritionErrorCopy._();

  static String failedAssessment(String? code) => switch (code) {
        NutritionErrorCodes.aiNotConfigured =>
          'Dịch vụ AI chưa được bật hoặc thiếu API key trên máy chủ. Thông tin đã nhập vẫn được giữ.',
        NutritionErrorCodes.aiAuthenticationFailed =>
          'API key của dịch vụ AI không hợp lệ hoặc không có quyền. Quản trị viên cần cập nhật key trên máy chủ.',
        NutritionErrorCodes.aiConfigurationInvalid =>
          'Cấu hình model hoặc endpoint AI không hợp lệ. Quản trị viên cần kiểm tra cấu hình máy chủ.',
        NutritionErrorCodes.aiRateLimited =>
          'Dịch vụ AI đang giới hạn lượt gọi. Vui lòng thử lại sau; thông tin đã nhập vẫn được giữ.',
        NutritionErrorCodes.aiTimeout =>
          'Dịch vụ AI phản hồi quá thời gian. Vui lòng thử lại; thông tin đã nhập vẫn được giữ.',
        NutritionErrorCodes.aiBudgetExhausted =>
          'Ngân sách gọi AI trong ngày đã hết. Vui lòng thử lại sau.',
        NutritionErrorCodes.aiInvalidOutput =>
          'Dịch vụ AI trả về dữ liệu không hợp lệ. Vui lòng thử lại.',
        NutritionErrorCodes.aiRefused =>
          'Dịch vụ AI từ chối xử lý nội dung này. Hãy kiểm tra lại phần mô tả sức khỏe.',
        NutritionErrorCodes.aiInputTooLarge =>
          'Thông tin sức khỏe quá dài để phân tích. Hãy rút gọn nội dung rồi thử lại.',
        NutritionErrorCodes.aiUnavailable =>
          'Không kết nối được dịch vụ AI. Vui lòng thử lại sau; thông tin đã nhập vẫn được giữ.',
        _ => 'Phân tích chưa thành công. Thông tin đã nhập vẫn được giữ.',
      };
}
