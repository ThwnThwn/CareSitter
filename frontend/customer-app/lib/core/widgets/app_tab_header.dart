import 'package:flutter/material.dart';

import '../theme/app_font_sizes.dart';
import '../theme/app_theme.dart';

/// Heading for pages in the main Customer tabs.
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({
    super.key,
    required this.title,
    required this.topPadding,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final double topPadding;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.section,
          topPadding + AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final buttonCount = actions.length + (leading == null ? 0 : 1);
          final titleRoom = textScaler.scale(150);
          final stackActions = actions.length > 1 &&
              constraints.maxWidth <
                  titleRoom + buttonCount * kMinInteractiveDimension;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: kMinInteractiveDimension),
                child: Row(
                  children: [
                    if (leading case final button?) ...[
                      button,
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppFontSizes.s22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (!stackActions && actions.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      ...actions,
                    ],
                  ],
                ),
              ),
              if (stackActions) Wrap(children: actions),
            ],
          );
        }),
      );
}
