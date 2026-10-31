import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/service_detail_profile.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_checklist_section.dart';
import 'package:flutter/material.dart';

class ServiceDetailSections extends StatelessWidget {
  const ServiceDetailSections({
    super.key,
    required this.service,
    required this.profile,
    required this.checklistItems,
    required this.checklistLoading,
    required this.onRetryChecklist,
    this.checklistError,
  });

  final ServiceModel service;
  final ServiceDetailProfile profile;
  final List<ServiceChecklistItemModel> checklistItems;
  final bool checklistLoading;
  final String? checklistError;
  final VoidCallback onRetryChecklist;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ServiceTypeBadge(),
          const SizedBox(height: AppSpacing.compact),
          _ServiceIntroduction(service: service, profile: profile),
          const SizedBox(height: AppSpacing.md),
          _ServiceFacts(service: service),
          if (service.activePlans.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _ServicePlans(service: service),
          ],
          const SizedBox(height: AppSpacing.xl),
          ServiceChecklistSection(
            items: checklistItems,
            loading: checklistLoading,
            error: checklistError,
            onRetry: onRetryChecklist,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SafetyCommitment(),
        ],
      );
}

class _ServicePlans extends StatelessWidget {
  const _ServicePlans({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phương án dịch vụ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...service.activePlans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.compact),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.micro),
                          Text(
                            '${plan.includedSessions} buổi · ${plan.durationMinutes} phút/buổi'
                            '${plan.validityDays == null ? '' : ' · ${plan.validityDays} ngày'}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatPrice(plan.totalPrice),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  static String _formatPrice(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return '$bufferđ';
  }
}

class _ServiceTypeBadge extends StatelessWidget {
  const _ServiceTypeBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Text(
          'CHĂM SÓC PHI Y TẾ',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
          ),
        ),
      );
}

class _ServiceIntroduction extends StatelessWidget {
  const _ServiceIntroduction({required this.service, required this.profile});

  final ServiceModel service;
  final ServiceDetailProfile profile;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            service.description?.trim().isNotEmpty == true
                ? service.description!.trim()
                : profile.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
          ),
        ],
      );
}

class _ServiceFacts extends StatelessWidget {
  const _ServiceFacts({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _FactChip(
            icon: Icons.schedule_rounded,
            label: _durationLabel(service.defaultDurationMinutes),
          ),
          const _FactChip(
            icon: Icons.verified_user_outlined,
            label: 'Caregiver đã xác minh',
          ),
          const _FactChip(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Có nhật ký chăm sóc',
          ),
        ],
      );

  static String _durationLabel(int minutes) {
    if (minutes <= 0) return 'Thời lượng linh hoạt';
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? '${hours.toInt()} giờ gợi ý'
        : '${hours.toStringAsFixed(1)} giờ gợi ý';
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: AppSpacing.tight),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _SafetyCommitment extends StatelessWidget {
  const _SafetyCommitment();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Cam kết CareSitter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'Caregiver được xác minh hồ sơ • Giá và phạm vi công việc minh bạch • Gia đình theo dõi nhật ký ca chăm sóc.',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Dịch vụ không thay thế khám, chẩn đoán, điều trị hoặc thực hiện thủ thuật y tế.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}
