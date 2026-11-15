import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../../caregiver/data/models/caregiver_model.dart';
import '../../data/repositories/booking_repository.dart';

typedef BookingCandidateInput = ({
  String? beneficiaryId,
  String addressId,
  String serviceTypeId,
  DateTime start,
  DateTime end,
  String requiredSkillsJson
});

final bookingCandidateRequestProvider = FutureProvider.autoDispose
    .family<List<CaregiverModel>, BookingCandidateInput>((ref, input) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  return ref.read(bookingRepositoryProvider).previewCaregivers(
      beneficiaryId: input.beneficiaryId,
      addressId: input.addressId,
      serviceTypeId: input.serviceTypeId,
      start: input.start,
      end: input.end,
      requiredSkills: (jsonDecode(input.requiredSkillsJson) as List<dynamic>)
          .cast<String>());
});
