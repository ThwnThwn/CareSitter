import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroCaregiverAvatars extends StatelessWidget {
  const HomeHeroCaregiverAvatars({super.key});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuB_gclqxTQn4Hcbz-83_gEg_MI4goQwj5nYiQZUd0zrWDfoybrs5j468EvYpccjQIJJFrVTI67wuoh7Z0NRIGF9MxbDKSyHNoKOlk8yxNHqzA_mqeKF7jbE0KUjwdrUuQMtcP4g5I-YO-UoQ_iiLGbRsTCfz0c2CEvq8BKN0pgJWk0gyVm9-tgZPvsg7bkPlycqYWLBLVb3r6bsGe--8-MHnPdrZh43tjpZrrx2BFVCpqArNmmv3QK9',
        memCacheWidth: 1200,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) =>
            const ColoredBox(color: AppColors.primaryContainer),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          color: AppColors.primaryContainer,
          child: const Icon(Icons.elderly_woman_rounded,
              size: 80, color: AppColors.primary),
        ),
      );
}
