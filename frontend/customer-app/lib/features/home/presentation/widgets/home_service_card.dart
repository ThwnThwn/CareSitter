import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import '../models/home_service_accent.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard(
      {super.key,
      required this.service,
      required this.accent,
      required this.formatVnd});
  final ServiceModel service;
  final HomeServiceAccent accent;
  final String Function(int) formatVnd;
  @override
  Widget build(BuildContext context) {
    final serviceId = Uri.encodeComponent(service.id);
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return HomeHoverButton(
      onTap: () => context.push('/booking/new?serviceId=$serviceId'),
      child: Container(
        width: 138 * textScale,
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: accent.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: accent.color.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  service.icon,
                  style: const TextStyle(fontSize: AppFontSizes.s20),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const Spacer(),
            if (service.baseHourlyPrice > 0)
              Text(
                '${formatVnd(service.baseHourlyPrice)}/giờ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.color,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                '${service.defaultDurationMinutes} phút',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.color,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
