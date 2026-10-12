import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_section_card.dart';

/// Section hiển thị gallery ảnh minh chứng của ca.
class ReportPhotoGallery extends StatelessWidget {
  final List<String> taskPhotos;

  const ReportPhotoGallery({
    super.key,
    required this.taskPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final urls = taskPhotos.where((url) => url.startsWith('http')).toList();
    return ReportSectionCard(
      title: '📷 Ảnh minh chứng',
      subtitle: '${urls.length} ảnh',
      child: urls.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.comfortable),
              child: Text('Chưa có ảnh minh chứng được tải lên.',
                  style: TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: AppColors.textSecondary)),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: urls.length,
              itemBuilder: (ctx, i) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(urls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppColors.textHint))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
