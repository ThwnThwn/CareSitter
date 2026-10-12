import 'package:caresitter_customer/features/home/presentation/widgets/home_nearby_caregiver_results.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_nearby_caregiver_header.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_nearby_caregiver_location.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverSection extends StatelessWidget {
  const HomeCaregiverSection(
      {super.key,
      required this.ref,
      required this.buildCaregiverEmptyState,
      required this.buildCaregiverCard});
  final WidgetRef ref;
  final Widget Function(BuildContext, {required bool hasLocation})
      buildCaregiverEmptyState;
  final Widget Function(CaregiverModel, BuildContext) buildCaregiverCard;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeNearbyCaregiverHeader(
            callbackAction1: () => context.go('/caregivers')),
        const SizedBox(height: AppSpacing.inset),
        HomeNearbyCaregiverLocation(
            ref: ref,
            callbackAction1: () => ref.invalidate(addressStoreProvider),
            callbackAction2: (id) =>
                ref.read(caregiverSearchAddressIdProvider.notifier).state = id),
        const SizedBox(height: AppSpacing.inset),
        HomeNearbyCaregiverResults(
            buildCaregiverEmptyState: buildCaregiverEmptyState,
            buildCaregiverCard: buildCaregiverCard),
      ],
    );
  }
}
