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
    final priceLabel = service.minimumPlanPrice > 0
        ? 'Từ ${formatVnd(service.minimumPlanPrice)}/buổi'
        : service.baseHourlyPrice > 0
            ? 'Từ ${formatVnd(service.baseHourlyPrice)}/giờ'
            : _durationLabel(service.defaultDurationMinutes);

    return _HomeServiceCardSurface(
      semanticsLabel: '${service.name}, $ratingLabel sao, $priceLabel, '
          '${_durationLabel(service.defaultDurationMinutes)}',
      width: 156 + (textScale - 1) * 32,
      height: 168 + (textScale - 1) * 32,
      borderRadius: borderRadius,
      imageAsset: imageAsset,
      imageUrl: service.imageUrl,
      imageKey: Key('home-service-image-${service.code}'),
      accent: accent,
      ratingLabel: ratingLabel,
      serviceName: service.name,
      priceLabel: priceLabel,
      textScale: textScale,
      onTap: () => context.push(AppRoutes.serviceDetail(service.id)),
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
    if (normalized.contains('THAN_TRI')) {
      return 'assets/images/service-essential.jpg';
    }
    if (normalized.contains('AN_KHANG')) {
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

class _HomeServiceCardSurface extends StatelessWidget {
  const _HomeServiceCardSurface({
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
                _HomeServiceImage(
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

class _HomeServiceImage extends StatelessWidget {
  const _HomeServiceImage({
    required this.imageUrl,
    required this.imageAsset,
    required this.imageKey,
    required this.accent,
  });

  final String? imageUrl;
  final String imageAsset;
  final Key imageKey;
  final HomeServiceAccent accent;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        key: imageKey,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _assetImage(),
      );
    }
    return _assetImage();
  }

  Widget _assetImage() => Image.asset(
        imageAsset,
        key: imageKey,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ImageFallback(accent: accent),
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
