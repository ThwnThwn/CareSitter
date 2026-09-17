import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    this.expanded = false,
  });

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final hero = LayoutBuilder(
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
          child: Stack(
            children: [
              const Positioned.fill(
                child: _ResponsiveDecorations(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  expanded ? AppSpacing.xxl : AppSpacing.xl,
                  horizontalPadding,
                  AppSpacing.xl,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'CareSitter',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontSize: compact ? 27 : 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Chăm sóc người thân, trao gửi yêu thương',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return expanded ? SizedBox.expand(child: hero) : hero;
  }
}

class _ResponsiveDecorations extends StatelessWidget {
  const _ResponsiveDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: const Alignment(1.25, -1.25),
          child: FractionallySizedBox(
            widthFactor: 0.42,
            child: _circle(0.07),
          ),
        ),
        Align(
          alignment: const Alignment(-1.18, 1.18),
          child: FractionallySizedBox(
            widthFactor: 0.29,
            child: _circle(0.06),
          ),
        ),
        Align(
          alignment: const Alignment(0.72, 0.68),
          child: FractionallySizedBox(
            widthFactor: 0.15,
            child: _circle(0.08),
          ),
        ),
      ],
    );
  }

  Widget _circle(double opacity) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
