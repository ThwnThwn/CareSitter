import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';

class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: onPrevious, child: const Text('Trước')),
            Text('Trang $page'),
            TextButton(onPressed: onNext, child: const Text('Sau')),
          ],
        ),
      );
}
