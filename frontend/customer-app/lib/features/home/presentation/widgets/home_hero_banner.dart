import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_card.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_booking_button.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_caregiver_avatars.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_caregiver_count.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_image.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner(
      {super.key,
      required this.caregiverSearchController,
      required this.openCaregiverSearch});
  final TextEditingController caregiverSearchController;
  final void Function([String?]) openCaregiverSearch;
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final heroHeight = (isNarrow ? 352.0 : 320.0) + ((textScale - 1) * 150);
    final stats = HomeHeroCaregiverCount(isNarrow: isNarrow);
    final callToAction = HomeHeroBookingButton(
        isNarrow: isNarrow,
        callbackAction1: () => context.push(AppRoutes.bookingNew));
    return SizedBox(
      key: const Key('home-hero-banner'),
      height: heroHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            const HomeHeroCaregiverAvatars(),

            // Gradient overlay (bottom-heavy dark)
            const HomeHeroImage(),

            // Content
            HomeHeroCard(
                isNarrow: isNarrow,
                stats: stats,
                callToAction: callToAction,
                caregiverSearchController: caregiverSearchController,
                openCaregiverSearch: openCaregiverSearch,
                callbackAction1: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus()),
          ],
        ),
      ),
    );
  }
}
