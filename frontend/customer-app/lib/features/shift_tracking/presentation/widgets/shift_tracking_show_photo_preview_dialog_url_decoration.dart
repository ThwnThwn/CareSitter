import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingShowPhotoPreviewDialogUrlDecoration extends StatelessWidget {
  const ShiftTrackingShowPhotoPreviewDialogUrlDecoration(
      {super.key, required this.url, required this.action1});
  final String url;
  final void Function() action1;
  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  color: Colors.black87,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: Colors.white70, size: 48),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Không thể tải ảnh',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              onPressed: action1,
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
}
