import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';

/// Card chọn người thân trong bước 2 của booking wizard.
/// Nhận [beneficiary], trạng thái [isSelected] và [onTap] từ bước cha —
/// không đọc provider nội bộ.
class RecipientCard extends StatelessWidget {
  const RecipientCard({
    super.key,
    required this.beneficiary,
    required this.isSelected,
    required this.onTap,
  });

  final BeneficiaryModel beneficiary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${beneficiary.name}, ${beneficiary.ageLabel}, ${beneficiary.relation}',
      button: true,
      selected: isSelected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: _cardDecoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.compact,
              ),
              child: Row(
                children: [
                  _BeneficiaryAvatar(
                      beneficiary: beneficiary, selected: isSelected),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _BeneficiaryInfo(beneficiary: beneficiary)),
                  const SizedBox(width: AppSpacing.sm),
                  _SelectionIndicator(selected: isSelected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: isSelected ? AppColors.primaryContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );
}

// ── Thông tin người thân ─────────────────────────────────────────────────────

class _BeneficiaryInfo extends StatelessWidget {
  const _BeneficiaryInfo({required this.beneficiary});

  final BeneficiaryModel beneficiary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          beneficiary.name,
          style: const TextStyle(
            fontSize: AppFontSizes.s15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          '${beneficiary.ageLabel} • ${beneficiary.relation}',
          style: const TextStyle(
            fontSize: AppFontSizes.s13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Avatar tròn ──────────────────────────────────────────────────────────────

class _BeneficiaryAvatar extends StatelessWidget {
  const _BeneficiaryAvatar({
    required this.beneficiary,
    required this.selected,
  });

  final BeneficiaryModel beneficiary;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final path = beneficiary.avatarPath;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : AppColors.primaryContainer,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null && path.isNotEmpty
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialText(
                initial: beneficiary.avatarInitial,
                selected: selected,
              ),
            )
          : _InitialText(
              initial: beneficiary.avatarInitial,
              selected: selected,
            ),
    );
  }
}

class _InitialText extends StatelessWidget {
  const _InitialText({required this.initial, required this.selected});

  final String initial;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: AppFontSizes.s15,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Chỉ báo chọn ─────────────────────────────────────────────────────────────

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: selected
          ? Container(
              key: const ValueKey('selected'),
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            )
          : Container(
              key: const ValueKey('unselected'),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline, width: 1.5),
              ),
            ),
    );
  }
}
