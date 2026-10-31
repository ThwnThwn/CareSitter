import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Ảnh dịch vụ dùng chung cho danh mục và bước chọn dịch vụ khi đặt lịch.
class ServiceImage extends StatelessWidget {
  const ServiceImage({
    super.key,
    required this.code,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallbackBackground,
    required this.fallbackForeground,
  });

  final String code;
  final String? imageUrl;
  final double width;
  final double height;
  final Color fallbackBackground;
  final Color fallbackForeground;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: width,
          height: height,
          child: _image(),
        ),
      );

  Widget _image() {
    final url = imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => _assetImage(),
      );
    }
    return _assetImage();
  }

  Widget _assetImage() => Image.asset(
        _assetFor(code),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: fallbackBackground,
          child: Center(
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: fallbackForeground,
              size: 32,
            ),
          ),
        ),
      );

  static String _assetFor(String code) {
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
}
