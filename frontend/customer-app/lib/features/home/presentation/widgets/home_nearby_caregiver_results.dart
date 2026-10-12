import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeNearbyCaregiverResults extends StatelessWidget {
  const HomeNearbyCaregiverResults(
      {super.key,
      required this.buildCaregiverEmptyState,
      required this.buildCaregiverCard});
  final Widget Function(BuildContext, {required bool hasLocation})
      buildCaregiverEmptyState;
  final Widget Function(CaregiverModel, BuildContext) buildCaregiverCard;

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (context, ref, _) {
          final caregiverAsync = ref.watch(nearbyCaregiversProvider);
          return caregiverAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
            error: (_, __) => Column(children: [
              const Text('Chưa tải được chăm sóc viên gần địa chỉ này.'),
              TextButton(
                  onPressed: () => ref.invalidate(nearbyCaregiversProvider),
                  child: const Text('Thử lại')),
            ]),
            data: (caregivers) {
              if (caregivers.isEmpty) {
                return buildCaregiverEmptyState(context,
                    hasLocation:
                        ref.watch(caregiverSearchAddressProvider).valueOrNull !=
                            null);
              }
              final preview = caregivers.take(5).toList();
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      for (var i = 0; i < preview.length; i++) ...[
                        buildCaregiverCard(preview[i], context),
                        if (i != preview.length - 1)
                          const SizedBox(width: AppSpacing.compact),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
}
