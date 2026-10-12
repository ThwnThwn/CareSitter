import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_brand.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class AuthHeroLayout extends StatelessWidget {
  const AuthHeroLayout({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < AppBreakpoints.compact;
          final horizontalPadding =
              compact ? AppSpacing.md : AppSpacing.lg + AppSpacing.xs;

          return Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: AppLayout.authHeroMinHeight,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: expanded
                  ? const BorderRadius.only(
                      topRight: Radius.circular(AppSpacing.xl),
                      bottomRight: Radius.circular(AppSpacing.xl),
                    )
                  : const BorderRadius.only(
                      bottomLeft: Radius.circular(AppSpacing.xl),
                      bottomRight: Radius.circular(AppSpacing.xl),
                    ),
            ),
            clipBehavior: Clip.antiAlias,
            child: AuthHeroBrand(
                horizontalPadding: horizontalPadding,
                expanded: expanded,
                compact: compact),
          );
        },
      );
}
