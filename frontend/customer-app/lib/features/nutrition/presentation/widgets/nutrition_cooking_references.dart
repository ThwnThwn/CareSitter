import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_reference_text.dart';

/// Curated outbound links only: no recipe content or images are imported.
class NutritionCookingReferences extends StatelessWidget {
  const NutritionCookingReferences({super.key});

  static const recipeUrl = 'https://monngonmoingay.com/lau-thai-chua-cay/';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text('Tham khảo cách nấu',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Mở website gốc để đọc công thức. Đây là tài liệu nấu ăn đọc thêm, chưa được đối chiếu với hồ sơ sức khỏe của bạn.',
          ),
          const NutritionReferenceText(
            recipeUrl,
            label: 'Món Ngon Mỗi Ngày · Lẩu Thái chua cay ↗',
          ),
          Text('Nguồn: Món Ngon Mỗi Ngày — Ajinomoto Việt Nam',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Khẩu phần, gia vị và số liệu trên website có thể khác công thức CareSitter. Liên kết này không phải nguồn tính dinh dưỡng của thực đơn hiện tại.',
          ),
        ],
      );
}
