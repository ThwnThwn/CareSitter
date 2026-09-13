import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Fixed-size placeholders keep the first-load layout stable.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    final content = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          CircleAvatar(radius: 28, backgroundColor: AppColors.border),
          SizedBox(width: 16),
          Expanded(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 16,
                  width: double.infinity,
                  child: ColoredBox(color: AppColors.border)),
              SizedBox(height: 12),
              SizedBox(
                  height: 12,
                  width: 100,
                  child: ColoredBox(color: AppColors.border)),
            ],
          )),
        ]),
      ),
    );
    return Semantics(
      label: 'Đang tải danh sách',
      liveRegion: true,
      child: ExcludeSemantics(
          child: MediaQuery.of(context).disableAnimations
              ? content
              : Shimmer.fromColors(
                  baseColor: AppColors.border,
                  highlightColor: AppColors.surface,
                  child: content,
                )),
    );
  }
}
