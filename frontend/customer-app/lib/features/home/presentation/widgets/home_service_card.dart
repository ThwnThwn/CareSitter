import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import '../models/home_service_accent.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard({
    super.key,
    required this.service,
    required this.accent,
    required this.formatVnd,
  });

  final ServiceModel service;
  final HomeServiceAccent accent;
  final String Function(int) formatVnd;

  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();
    final borderRadius = BorderRadius.circular(AppRadius.lg);
    final imageAsset = _imageAssetFor(service.code);
    final ratingLabel = _ratingFor(service.code).toStringAsFixed(1);
    final priceLabel = service.baseHourlyPrice > 0
        ? 'Từ ${formatVnd(service.baseHourlyPrice)}/giờ'
        : _durationLabel(service.defaultDurationMinutes);

    return Semantics(
      label: '${service.name}, $ratingLabel sao, $priceLabel, '
          '${_durationLabel(service.defaultDurationMinutes)}',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 156 + (textScale - 1) * 32,
        height: 168 + (textScale - 1) * 32,
        child: HomeHoverButton(
          borderRadius: borderRadius,
          onTap: () => context.push(
            AppRoutes.serviceDetail(service.id),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imageAsset,
                key: Key('home-service-image-${service.code}'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ImageFallback(accent: accent),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0A000000),
                      Color(0x24000000),
                      Color(0xD9000000),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.compact,
                right: AppSpacing.compact,
                child: Container(
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
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s11,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.compact,
                right: AppSpacing.compact,
                bottom: AppSpacing.compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 34 * textScale,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          service.name,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _imageAssetFor(String code) {
    final normalized = code.toUpperCase();
    if (normalized.contains('NONMED_COMPANION') ||
        normalized.contains('DONGHANH')) {
      return 'assets/images/service-companion.jpg';
    }
    if (normalized.contains('NONMED_ESSENTIAL')) {
      return 'assets/images/service-essential.jpg';
    }
    if (normalized.contains('NONMED_NIGHT') || normalized.contains('DEM')) {
      return 'assets/images/service-night.jpg';
    }
    return 'assets/images/service-day.jpg';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes phút';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours giờ';
    return '$hours giờ $remainingMinutes phút';
  }

  double _ratingFor(String code) {
    final normalized = code.toUpperCase();
    if (normalized.contains('NONMED_ESSENTIAL')) return 4.9;
    if (normalized.contains('NONMED_COMPANION') ||
        normalized.contains('DONGHANH')) {
      return 4.8;
    }
    if (normalized.contains('NONMED_NIGHT') || normalized.contains('DEM')) {
      return 4.9;
    }
    return 4.7;
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.accent});

  final HomeServiceAccent accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accent.background,
      child: Center(
        child: Icon(
          Icons.volunteer_activism_rounded,
          color: accent.color,
          size: 44,
        ),
      ),
    );
  }
}
