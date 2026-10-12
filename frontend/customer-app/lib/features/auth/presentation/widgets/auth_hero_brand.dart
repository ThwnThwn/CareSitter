import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_header_responsive_decorations.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class AuthHeroBrand extends StatelessWidget {
  const AuthHeroBrand(
      {super.key,
      required this.horizontalPadding,
      required this.expanded,
      required this.compact});
  final double horizontalPadding;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Positioned.fill(
            child: AuthHeroHeaderResponsiveDecorations(),
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
                    const SizedBox(height: AppSpacing.inset),
                    Text(
                      'CareSitter',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: AppFontSizes.s13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}
