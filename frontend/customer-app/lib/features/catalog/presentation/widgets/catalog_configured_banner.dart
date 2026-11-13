import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class CatalogConfiguredBanner extends ConsumerWidget {
  const CatalogConfiguredBanner({super.key, required this.builder});
  final Widget Function() builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(runtimeConfigControllerProvider
              .select((s) => s.config.catalogBannerEnabled))
          ? FadeSlideStaggered(index: 1, child: builder())
          : const SizedBox.shrink();
}
