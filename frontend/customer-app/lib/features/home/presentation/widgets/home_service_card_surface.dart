import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../models/home_service_accent.dart';

import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'home_hover_button.dart';
import 'home_service_card_image.dart';

class HomeServiceCardSurface extends StatelessWidget {
  const HomeServiceCardSurface({
    super.key,
    required this.semanticsLabel,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.imageAsset,
    required this.imageUrl,
    required this.imageKey,
    required this.accent,
    required this.ratingLabel,
    required this.serviceName,
    required this.priceLabel,
    required this.textScale,
    required this.onTap,
  });

  final String semanticsLabel;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final String imageAsset;
  final String? imageUrl;
  final Key imageKey;
  final HomeServiceAccent accent;
  final String ratingLabel;
  final String serviceName;
  final String priceLabel;
  final double textScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        button: true,
        excludeSemantics: true,
        child: SizedBox(
          width: width,
          height: height,
          child: HomeHoverButton(
            borderRadius: borderRadius,
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HomeServiceCardImage(
                  imageUrl: imageUrl,
                  imageAsset: imageAsset,
                  imageKey: imageKey,
                  accent: accent,
                ),
                const _ServiceCardScrim(),
                Positioned(
                  top: AppSpacing.compact,
                  right: AppSpacing.compact,
                  child: _ServiceRatingBadge(label: ratingLabel),
                ),
                Positioned(
                  left: AppSpacing.compact,
                  right: AppSpacing.compact,
                  bottom: AppSpacing.compact,
                  child: _ServiceCardCaption(
                    serviceName: serviceName,
                    priceLabel: priceLabel,
                    textScale: textScale,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ServiceCardScrim extends StatelessWidget {
  const _ServiceCardScrim();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0A000000), Color(0x24000000), Color(0xD9000000)],
            stops: [0, 0.48, 1],
          ),
        ),
      );
}

class _ServiceRatingBadge extends StatelessWidget {
  const _ServiceRatingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
}

class _ServiceCardCaption extends StatelessWidget {
  const _ServiceCardCaption({
    required this.serviceName,
    required this.priceLabel,
    required this.textScale,
  });

  final String serviceName;
  final String priceLabel;
  final double textScale;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34 * textScale,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                serviceName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            priceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      );
}
