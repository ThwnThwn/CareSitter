import 'package:flutter/material.dart';
import '../models/home_service_accent.dart';

class HomeServiceCardImage extends StatelessWidget {
  const HomeServiceCardImage({
    super.key,
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
