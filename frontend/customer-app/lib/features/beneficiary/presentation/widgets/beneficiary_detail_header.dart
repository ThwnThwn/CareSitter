import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_avatar_image.dart';

class BeneficiaryDetailHeader extends StatelessWidget {
  const BeneficiaryDetailHeader({super.key, required this.b});
  final BeneficiaryModel b;
  @override
  Widget build(BuildContext context) => SliverAppBar(
        pinned: true,
        expandedHeight: 220,
        backgroundColor: AppColors.primary,
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.beneficiaries,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () =>
                context.push(AppRoutes.beneficiaryEdit(b.id)).then((_) {
              if (context.mounted) (context as Element).markNeedsBuild();
            }),
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: AppSpacing.xxl),
              (() {
                final hasAvatar =
                    b.avatarPath != null && b.avatarPath!.isNotEmpty;
                final defaultAvatarPath = defaultAvatarAssetForGender(
                  age: b.age,
                  gender: b.gender,
                );
                return CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  backgroundImage: hasAvatar
                      ? beneficiaryAvatarImageProvider(b.avatarPath!)
                      : defaultAvatarPath == null
                          ? null
                          : AssetImage(defaultAvatarPath),
                  onBackgroundImageError: hasAvatar || defaultAvatarPath != null
                      ? (_, __) {}
                      : null,
                  child: !hasAvatar && defaultAvatarPath == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 42,
                        )
                      : null,
                );
              })(),
              const SizedBox(height: AppSpacing.sm),
              Text(b.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppFontSizes.s18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              Text('${b.ageLabel} · ${b.relation}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: AppFontSizes.s13)),
            ]),
          ),
        ),
      );
}
