import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Nút chia sẻ báo cáo ca.
class ReportShareButton extends StatelessWidget {
  final VoidCallback onShare;

  const ReportShareButton({
    super.key,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.share_rounded),
      label: const Text('Chia sẻ báo cáo'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      onPressed: onShare,
    );
  }
}
