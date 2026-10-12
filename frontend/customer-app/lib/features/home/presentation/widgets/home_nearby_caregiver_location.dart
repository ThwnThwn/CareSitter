import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/core/widgets/location_selector.dart';

class HomeNearbyCaregiverLocation extends StatelessWidget {
  const HomeNearbyCaregiverLocation(
      {super.key,
      required this.ref,
      required this.callbackAction1,
      required this.callbackAction2});
  final WidgetRef ref;
  final void Function() callbackAction1;
  final void Function(String) callbackAction2;

  @override
  Widget build(BuildContext context) => LocationSelector(
      loading: ref.watch(caregiverSearchAddressProvider).isLoading,
      failed: ref.watch(caregiverSearchAddressProvider).hasError,
      selectedId: ref.watch(caregiverSearchAddressProvider).valueOrNull?.id,
      shortAddress:
          ref.watch(caregiverSearchAddressProvider).valueOrNull?.shortAddress,
      onRetry: callbackAction1,
      onSelected: callbackAction2);
}
