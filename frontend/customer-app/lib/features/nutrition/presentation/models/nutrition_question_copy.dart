import '../../data/models/nutrition_question_model.dart';

class NutritionQuestionCopy {
  const NutritionQuestionCopy._();

  static String title(NutritionQuestionModel question) =>
      <String, String>{
        'confirm_subject':
            'Thông tin này nói về người được hỗ trợ hay một người khác?',
        'confirm_assertion':
            'Thông tin này đang có, không có hay gia đình chưa rõ?',
        'confirm_temporality':
            'Thông tin này thuộc hiện tại hay đã xảy ra trước đây?',
        'resolve_food_allergy_conflict':
            'Thông tin dị ứng thực phẩm đang khác nhau giữa các nguồn.',
        'resolve_condition_conflict':
            'Thông tin tình trạng sức khỏe đang khác nhau giữa các nguồn.',
        'resolve_medication_conflict':
            'Thông tin thuốc đang dùng đang khác nhau giữa các nguồn.',
        'resolve_source_conflict':
            'Có thông tin sức khỏe chưa thống nhất trong hồ sơ.',
        'confirm_food_allergy_status':
            'Người được hỗ trợ có dị ứng thực phẩm không?',
        'list_food_allergies':
            'Vui lòng ghi rõ thực phẩm đã được gia đình báo cáo là gây dị ứng.',
        'confirm_condition_status':
            'Hồ sơ đã ghi đủ tình trạng sức khỏe hiện có chưa?',
        'list_reported_conditions':
            'Vui lòng bổ sung tình trạng sức khỏe gia đình đã được thông báo.',
        'confirm_medication_status':
            'Người được hỗ trợ hiện có dùng thuốc không?',
        'list_current_medications':
            'Vui lòng bổ sung thuốc đang dùng theo thông tin hiện có.',
        'confirm_date_of_birth': 'Vui lòng kiểm tra ngày sinh trong hồ sơ.',
        'confirm_feeding_route': 'Người được hỗ trợ ăn bằng đường nào?',
        'confirm_swallowing_status':
            'Khả năng nhai nuốt hiện tại đã được ghi đúng chưa?',
        'confirm_fluid_restriction':
            'Gia đình có hướng dẫn hiện có về hạn chế nước không?',
        'confirm_electrolyte_restriction':
            'Gia đình có hướng dẫn hiện có về điện giải không?',
        'review_uncertain_health_information':
            'Có thông tin sức khỏe chưa chắc chắn cần kiểm tra lại.',
        'identify_health_information':
            'Có nội dung sức khỏe hệ thống chưa nhận diện được.',
        'add_required_detail':
            'Thông tin hiện có chưa đủ chi tiết để tiếp tục.',
        'review_unresolved_information':
            'Vui lòng kiểm tra lại phần lưu ý sức khỏe chưa rõ.',
        'complete_required_health_information':
            'Hồ sơ còn thiếu thông tin cần thiết để tiếp tục.',
      }[question.purpose] ??
      'Vui lòng kiểm tra lại thông tin sức khỏe.';

  static String hint(NutritionQuestionModel question) =>
      question.inputType == 'single_choice'
          ? 'Chọn thông tin đúng trong hồ sơ; có thể chọn “Chưa rõ”.'
          : 'Cập nhật hồ sơ nguồn rồi kiểm tra lại để tránh dùng thông tin cũ.';
}
