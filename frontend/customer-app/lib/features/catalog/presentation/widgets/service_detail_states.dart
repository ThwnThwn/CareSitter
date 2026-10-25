import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ServiceDetailError extends StatelessWidget {
  const ServiceDetailError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết dịch vụ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Chưa tải được thông tin dịch vụ.'),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
}

class ServiceDetailNotFound extends StatelessWidget {
  const ServiceDetailNotFound({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết dịch vụ')),
        body: const Center(child: Text('Không tìm thấy dịch vụ này.')),
      );
}
