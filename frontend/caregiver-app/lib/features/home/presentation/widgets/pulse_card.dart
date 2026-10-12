import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';

/// Pulsing card border animation
class PulseCard extends StatefulWidget {
  final Widget child;
  const PulseCard({super.key, required this.child});

  @override
  State<PulseCard> createState() => PulseCardState();
}

class PulseCardState extends State<PulseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withValues(alpha: 0.35 - (_anim.value / 20)),
                blurRadius: _anim.value,
                spreadRadius: 0,
              ),
              ...AppShadows.elevated,
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
