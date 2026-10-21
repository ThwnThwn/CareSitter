import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// BookingStepIndicator theo Stitch design:
/// Step dots lớn hơn (w-7), checkmark cho bước done, ring brand khi active,
/// badge "Bước X/6" ở góc phải, connector track mỏng.
class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({super.key, required this.step});
  final int step;

  static const titles = [
    'Dịch vụ',
    'Người nhận',
    'Lịch & địa chỉ',
    'Chăm sóc viên',
    'Đồng ý',
    'Xác nhận'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.compact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: step, titles: titles),
          const SizedBox(height: AppSpacing.compact),
          _StepTrack(step: step, titles: titles),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(
          step < titles.length ? titles[step] : '',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            'Bước ${step + 1}/${titles.length}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    ]);
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < titles.length; index++)
          Expanded(
            child: _StepItem(
              index: index,
              step: step,
              title: titles[index],
              count: titles.length,
            ),
          ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.index,
    required this.step,
    required this.title,
    required this.count,
  });

  final int index;
  final int step;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final completed = index < step;
    final active = index == step;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
            child: _StepConnector(visible: index > 0, active: index <= step)),
        _StepDot(index: index, completed: completed, active: active),
        Expanded(
          child: _StepConnector(visible: index < count - 1, active: completed),
        ),
      ]),
      const SizedBox(height: 4),
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active
              ? AppColors.primary
              : completed
                  ? AppColors.textSecondary
                  : AppColors.textHint,
          fontSize: 9,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ]);
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.visible, required this.active});
  final bool visible;
  final bool active;

  @override
  Widget build(BuildContext context) => visible
      ? Container(
          height: 2,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(1),
          ),
        )
      : const SizedBox.shrink();
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.completed,
    required this.active,
  });
  final int index;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            completed || active ? AppColors.primary : AppColors.surfaceVariant,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    spreadRadius: 4)
              ]
            : null,
      ),
      child: completed
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                color: active ? Colors.white : AppColors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
