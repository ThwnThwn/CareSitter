import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/features/booking/presentation/models/service_option_style.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class ServiceOptionCard extends StatefulWidget {
  const ServiceOptionCard({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceModel service;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ServiceOptionCard> createState() => _ServiceOptionCardState();
}

class _ServiceOptionCardState extends State<ServiceOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = ServiceOptionStyle.fromService(widget.service);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final transitionDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);
    final pressDuration = reduceMotion
        ? Duration.zero
        : Duration(milliseconds: _pressed ? 90 : 150);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.service.name,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: pressDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: transitionDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primaryContainer.withValues(alpha: 0.42)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: widget.selected ? AppColors.primary : AppColors.border,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.shadow,
                blurRadius: widget.selected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onHighlightChanged: (highlighted) {
                if (_pressed == highlighted) return;
                setState(() => _pressed = highlighted);
              },
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ServiceIcon(option: option),
                        const SizedBox(width: AppSpacing.inset),
                        Expanded(
                          child: _ServiceSummary(
                            option: option,
                            pricePerHour: widget.service.pricePerHour,
                            defaultDurationMinutes:
                                widget.service.defaultDurationMinutes,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _SelectionIndicator(selected: widget.selected),
                      ],
                    ),
                    if (widget.service.description?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(left: 60),
                        child: Text(
                          widget.service.description!.trim(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.option});

  final ServiceOptionStyle option;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: option.iconBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(option.icon, size: 24, color: option.iconForeground),
    );
  }
}

class _ServiceSummary extends StatelessWidget {
  const _ServiceSummary({
    required this.option,
    required this.pricePerHour,
    required this.defaultDurationMinutes,
  });

  final ServiceOptionStyle option;
  final double pricePerHour;
  final int defaultDurationMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.tight,
          runSpacing: AppSpacing.micro,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              option.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (option.subtitle != null)
              Text(
                option.subtitle!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              formatVnd(pricePerHour),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              '/giờ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          'Thời lượng gợi ý: ${_formatDuration(defaultDurationMinutes)}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60} giờ';
    return '${minutes ~/ 60} giờ ${minutes % 60} phút';
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: selected ? null : Border.all(color: AppColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: selected
            ? const Icon(
                Icons.check_rounded,
                key: ValueKey('selected'),
                size: 16,
                color: Colors.white,
              )
            : const SizedBox(key: ValueKey('unselected')),
      ),
    );
  }
}
