import '../../data/models/nutrition_source_model.dart';

class NutritionSourceCopy {
  static bool isAdapted(NutritionSourceModel source) =>
      source.id == 'CARESITTER_VARIETY_ADAPTATION_V2';

  static bool isComposition(NutritionSourceModel source) =>
      source.id == 'VIETNAM_FOOD_COMPOSITION_2017';

  static String role(NutritionSourceModel source) => isAdapted(source)
      ? 'Nguồn công thức'
      : isComposition(source)
          ? 'Nguồn số liệu thành phần thực phẩm'
          : 'Tài liệu tham khảo';

  static String title(NutritionSourceModel source) => isAdapted(source)
      ? 'Công thức thử nghiệm do CareSitter xây dựng'
      : source.title.isEmpty
          ? 'Nguồn chưa có tên hiển thị'
          : source.title;

  static bool isInternalPath(String value) {
    final normalized = value.trim().replaceAll('\\', '/').toLowerCase();
    return normalized.startsWith('backend/') ||
        normalized.startsWith('frontend/') ||
        normalized.startsWith('book/') ||
        normalized.startsWith('file:') ||
        normalized.startsWith('/') ||
        RegExp(r'^[a-z]:/').hasMatch(normalized);
  }

  static String reference(NutritionSourceModel source) => isAdapted(source)
      ? 'CareSitter phối hợp nguyên liệu và định lượng; công thức không được trích nguyên văn từ sách. Dưỡng chất là số liệu ước tính, chưa gồm gia vị bổ sung và hao hụt khi chế biến.'
      : isInternalPath(source.reference)
          ? ''
          : source.reference;
}
