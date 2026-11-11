import 'home_service_card_surface.dart';
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

    return HomeServiceCardSurface(
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
