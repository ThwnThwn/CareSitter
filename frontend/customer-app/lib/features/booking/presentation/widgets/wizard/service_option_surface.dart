import 'service_option_content.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/service_option_style.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class ServiceOptionSurface extends StatelessWidget {
  const ServiceOptionSurface({
    super.key,
    required this.service,
    required this.option,
    required this.selected,
    required this.pressed,
    required this.transitionDuration,
    required this.pressDuration,
    required this.onHighlightChanged,
    required this.onTap,
  });

  final ServiceModel service;
  final ServiceOptionStyle option;
  final bool selected;
  final bool pressed;
  final Duration transitionDuration;
  final Duration pressDuration;
  final ValueChanged<bool> onHighlightChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: service.name,
        child: AnimatedScale(
          scale: pressed ? 0.985 : 1,
          duration: pressDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: transitionDuration,
            curve: Curves.easeOutCubic,
            decoration: _decoration,
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onHighlightChanged: onHighlightChanged,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.inset),
                  child: ServiceOptionContent(
                    service: service,
                    option: option,
                    selected: selected,
                    transitionDuration: transitionDuration,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  BoxDecoration get _decoration => BoxDecoration(
        color: selected
            ? AppColors.primaryContainer.withValues(alpha: 0.42)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.shadow,
            blurRadius: selected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
