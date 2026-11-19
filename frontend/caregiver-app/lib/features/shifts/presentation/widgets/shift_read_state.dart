import 'package:flutter/material.dart';

import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_empty_state.dart';

class ShiftReadState extends StatelessWidget {
  const ShiftReadState({super.key, this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    if (failure == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (failure is AppApiException &&
        (failure.statusCode == 403 || failure.statusCode == 404)) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy ca làm việc',
        message: 'Ca này có thể đã bị hủy hoặc bạn không còn quyền xem.',
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chưa tải được thông tin ca.'),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
