import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Thanh tiến trình sáu bước theo màn booking trên Stitch.
class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({super.key, required this.step});
  final int step;

  static const titles = [
    'Dịch vụ',
    'Người nhận',
    'Lịch & địa chỉ',
    'Chăm sóc',
    'Đồng ý',
    'Xác nhận'
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.control,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: _StepTrack(step: step, titles: titles),
      ),
    );
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active
              ? AppColors.primary
              : completed
                  ? AppColors.textSecondary
                  : AppColors.textHint,
          fontSize: 10,
          height: 1.2,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return visible
        ? AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 2,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          )
        : const SizedBox.shrink();
  }
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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return AnimatedScale(
      scale: active ? 1.04 : 1,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: 28,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: completed || active
              ? AppColors.primary
              : AppColors.cardBackground,
          shape: BoxShape.circle,
          border:
              completed || active ? null : Border.all(color: AppColors.border),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: AppColors.primaryContainer,
                    spreadRadius: 4,
                  )
                ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: completed
              ? const Icon(
                  Icons.check_rounded,
                  key: ValueKey('completed'),
                  size: 14,
                  color: Colors.white,
                )
              : Text(
                  '${index + 1}',
                  key: ValueKey(index),
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textHint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
