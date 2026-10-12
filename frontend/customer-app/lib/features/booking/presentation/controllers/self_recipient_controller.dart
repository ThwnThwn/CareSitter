import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/settings/data/repositories/profile_repository.dart';

enum SelfRecipientKind { draft, existing, link }

final bookingRecipientsProvider =
    FutureProvider.autoDispose<List<BeneficiaryModel>>((ref) async {
  final userId = ref.watch(authStateProvider.select((s) => s.value?.userId));
  if (userId == null) return [];
  final records =
      await ref.read(beneficiaryRepositoryProvider).getBeneficiaries();
  return records.map(BeneficiaryModel.fromBackend).toList();
});

class SelfRecipient {
  final SelfRecipientKind kind;
  final BeneficiaryModel profile;
  const SelfRecipient(this.kind, this.profile);

  static String normalizePhone(String value) {
    final phone = value.replaceAll(RegExp(r'[\s().-]'), '');
    return phone.startsWith('+84') ? '0${phone.substring(3)}' : phone;
  }

  bool get isComplete {
    final contacts = profile.emergencyContacts;
    final phones = contacts.map((c) => normalizePhone(c.phone)).toSet();
    return profile.name.trim().isNotEmpty &&
        contacts.length >= 2 &&
        phones.length == contacts.length &&
        contacts.every((c) =>
            c.name.trim().isNotEmpty &&
            RegExp(r'^0[3-9][0-9]{8}$').hasMatch(normalizePhone(c.phone)));
  }
}

final selfRecipientProvider = StateNotifierProvider.autoDispose<
    SelfRecipientController, AsyncValue<SelfRecipient>>((ref) {
  final userId = ref.watch(authStateProvider.select((s) => s.value?.userId));
  return SelfRecipientController(ref.read(beneficiaryRepositoryProvider),
      ref.read(profileRepositoryProvider), userId);
});

class SelfRecipientController extends StateNotifier<AsyncValue<SelfRecipient>> {
  final BeneficiaryRepository repository;
  final ProfileRepository account;
  final String? userId;
  BeneficiaryModel? _draft;
  int _generation = 0;

  SelfRecipientController(this.repository, this.account, this.userId)
      : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      if (userId == null) throw StateError('Vui lòng đăng nhập lại.');
      final existing = await repository.getSelf();
      if (!mounted || generation != _generation) return;
      if (existing != null) {
        state = AsyncData(SelfRecipient(SelfRecipientKind.existing, existing));
        return;
      }
      final data = _draft == null ? await account.getFreshProfile() : null;
      if (!mounted || generation != _generation) return;
      _draft ??= BeneficiaryModel.fromBackend({
        ...data!,
        'id': '',
        'fullName': (data['fullName'] ?? data['FullName'])?.toString() ?? '',
        'isSelf': true,
        'relationshipToCustomer': 'Bản thân',
        'emergencyContacts': <dynamic>[]
      });
      state = AsyncData(SelfRecipient(SelfRecipientKind.draft, _draft!));
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  void updateDraft(BeneficiaryModel profile) {
    _draft = profile;
    state = AsyncData(SelfRecipient(SelfRecipientKind.draft, profile));
  }

  void selectLink(BeneficiaryModel profile) {
    state = AsyncData(SelfRecipient(SelfRecipientKind.link, profile));
  }

  void useDraft() {
    if (_draft != null) {
      state = AsyncData(SelfRecipient(SelfRecipientKind.draft, _draft!));
    }
  }

  void acceptExisting(BeneficiaryModel profile) {
    ++_generation;
    state = AsyncData(SelfRecipient(SelfRecipientKind.existing, profile));
  }

  Map<String, dynamic> _request(BeneficiaryModel profile, String addressId) => {
        ...profile.toProfileRequest(avatarUrl: profile.avatarPath)
          ..remove('RelationshipToCustomer'),
        'Phone': profile.phone,
        'DefaultAddressId': addressId,
      };

  String _fingerprint(BeneficiaryModel profile,
          {bool includeRelation = true}) =>
      jsonEncode({
        'name': profile.name,
        'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
        'gender': profile.gender,
        'phone': profile.phone,
        'mobilityNote': profile.mobilityNote,
        'healthHistory': profile.healthHistory,
        'allergies': profile.allergies,
        'chronicConditions': profile.chronicConditions,
        'medications': profile.medications,
        if (includeRelation) 'relation': profile.relation,
        'condition': profile.condition,
        'careLevel': profile.careLevel,
        'notes': profile.notes,
        'defaultAddressId': profile.defaultAddressId,
        'emergencyContacts':
            profile.emergencyContacts.map((c) => c.toJson()).toList(),
        'avatarPath': profile.avatarPath,
      });

  /// Chỉ gọi tại xác nhận cuối. Không cho một request chậm thay đổi phiên mới.
  Future<({BeneficiaryModel profile, bool needsReview})> resolve(
      String addressId) async {
    final selected = state.requireValue;
    if (!selected.isComplete) {
      throw StateError(
          'Vui lòng bổ sung thông tin chăm sóc và hai liên hệ khẩn cấp.');
    }
    BeneficiaryModel profile;
    var needsReview = false;
    try {
      switch (selected.kind) {
        case SelfRecipientKind.existing:
          profile = await repository.getBeneficiary(selected.profile.id);
          needsReview = _fingerprint(profile) != _fingerprint(selected.profile);
        case SelfRecipientKind.link:
          profile = await repository.linkSelf(selected.profile.id);
          needsReview = _fingerprint(profile, includeRelation: false) !=
              _fingerprint(selected.profile, includeRelation: false);
        case SelfRecipientKind.draft:
          final result = await repository
              .createSelf(_request(selected.profile, addressId));
          profile = result.beneficiary;
          needsReview = !result.created;
      }
    } on DioException catch (error) {
      // Sau lỗi mất response, GET xác minh; tuyệt đối không lặp POST booking.
      if (error.response != null) rethrow;
      final saved = await repository.getSelf();
      if (saved == null) rethrow;
      profile = saved;
      needsReview = true;
    }
    if (!mounted) throw StateError('Phiên đặt lịch đã kết thúc.');
    if (!profile.isSelf) {
      throw StateError('Hồ sơ bản thân đã thay đổi. Vui lòng tải lại.');
    }
    acceptExisting(profile);
    return (profile: profile, needsReview: needsReview);
  }
}
