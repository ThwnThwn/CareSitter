import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListFilteredHasLocationContent extends StatelessWidget {
  const CaregiverListFilteredHasLocationContent(
      {super.key,
      required this.filtered,
      required this.hasLocation,
      required this.allCaregivers,
      required this.buildCaregiverCard});
  final List<CaregiverModel> filtered;
  final bool hasLocation;
  final List<CaregiverModel> allCaregivers;
  final Widget Function(CaregiverModel, BuildContext) buildCaregiverCard;
  @override
  Widget build(BuildContext context) => Expanded(
        child: filtered.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasLocation ? Icons.search : Icons.location_on_outlined,
                      size: 40,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    Text(
                      !hasLocation
                          ? 'Chọn địa chỉ chăm sóc để xem người ở gần.'
                          : allCaregivers.isEmpty
                              ? 'Chưa có chăm sóc viên phục vụ địa chỉ này.\nThử đổi địa chỉ chăm sóc.'
                              : 'Không có chăm sóc viên khớp bộ lọc.\nThử đổi từ khóa hoặc trạng thái trực tuyến.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                key: const PageStorageKey('caregiver-list'),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.compact, AppSpacing.md, 100),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return FadeSlideStaggered(
                    key: ValueKey(filtered[index].id),
                    index: index,
                    child: buildCaregiverCard(filtered[index], context),
                  );
                },
              ),
      );
}
