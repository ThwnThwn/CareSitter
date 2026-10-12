import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import '../models/home_service_accent.dart';

class HomeServicesSection extends StatelessWidget {
  const HomeServicesSection(
      {super.key, required this.buildServiceCard, required this.serviceAccent});
  final Widget Function(ServiceModel, HomeServiceAccent) buildServiceCard;
  final HomeServiceAccent Function(int) serviceAccent;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dịch vụ nổi bật',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HomeHoverButton(
              onTap: () => context.push('/catalog'),
              child: const Text(
                'Tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.inset),
        Consumer(
          builder: (context, ref, _) {
            final servicesAsync = ref.watch(serviceStoreProvider);
            return servicesAsync.when(
              loading: () => const SizedBox(
                height: 128,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (services) {
                final featured = services;
                if (featured.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < featured.length; i++) ...[
                          buildServiceCard(featured[i], serviceAccent(i)),
                          if (i != featured.length - 1)
                            const SizedBox(width: AppSpacing.control),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
