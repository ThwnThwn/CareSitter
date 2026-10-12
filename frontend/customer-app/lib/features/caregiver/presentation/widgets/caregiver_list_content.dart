import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/core/widgets/location_selector.dart';

class CaregiverListContent extends StatelessWidget {
  const CaregiverListContent(
      {super.key,
      required this.ref,
      required this.action1,
      required this.action2});
  final WidgetRef ref;
  final void Function() action1;
  final void Function(String) action2;
  @override
  Widget build(BuildContext context) => LocationSelector(
      loading: ref.watch(caregiverSearchAddressProvider).isLoading,
      failed: ref.watch(caregiverSearchAddressProvider).hasError,
      selectedId: ref.watch(caregiverSearchAddressProvider).valueOrNull?.id,
      shortAddress:
          ref.watch(caregiverSearchAddressProvider).valueOrNull?.shortAddress,
      onRetry: action1,
      onSelected: action2);
}
