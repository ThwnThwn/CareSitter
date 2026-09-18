import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

export 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';

final beneficiaryStoreProvider =
    NotifierProvider<BeneficiaryStore, List<BeneficiaryModel>>(
  BeneficiaryStore.new,
);

class BeneficiaryStore extends Notifier<List<BeneficiaryModel>> {
  BeneficiaryRepository get _repository =>
      ref.read(beneficiaryRepositoryProvider);

  @override
  List<BeneficiaryModel> build() {
    // Lắng nghe đăng nhập để tải dữ liệu người thân của user thật
    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        _loadFromBackend();
      } else {
        state = const [];
      }
    });

    _loadFromBackend();
    // Tài khoản người dùng mới bắt đầu với danh sách rỗng
    return const [];
  }

  Future<void> _loadFromBackend() async {
    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;

    try {
      final addresses = await _readAddresses();
      final addressesById = {
        for (final address in addresses) address.id: address
      };
      final data = await _repository.getBeneficiaries();
      if (data.isNotEmpty) {
        final list = data
            .map((item) => _fromBackend(item, addressesById: addressesById))
            .toList();
        state = list;
      } else {
        state = const [];
      }
    } catch (_) {
      // Khi có lỗi mạng hoặc tài khoản mới chưa có data → giữ state hiện tại
    }
  }

  Future<BeneficiaryModel> add({
    required String name,
    required int age,
    required String relation,
    required String condition,
    required String careLevel,
    required String notes,
    required AddressModel defaultAddress,
    required List<EmergencyContact> emergencyContacts,
    XFile? avatarFile,
  }) async {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(3)
        .join();
    final localId = 'b${DateTime.now().millisecondsSinceEpoch}';
    final beneficiary = BeneficiaryModel(
      id: localId,
      name: name.trim(),
      age: age,
      relation: relation,
      avatarInitial: initials.isNotEmpty ? initials : 'B',
      condition: condition.isEmpty ? 'Chưa có ghi chú' : condition,
      careLevel: careLevel,
      notes: notes.trim(),
      address: defaultAddress.fullAddress,
      defaultAddressId: defaultAddress.id,
      emergencyContacts: [...emergencyContacts],
      avatarPath: avatarFile?.path,
    );
    final previousState = state;
    state = [...state, beneficiary];

    try {
      final synced = await _syncAddToBackend(beneficiary, avatarFile);
      return synced ?? beneficiary;
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<BeneficiaryModel?> _syncAddToBackend(
    BeneficiaryModel b,
    XFile? avatarFile,
  ) async {
    final approxBirthYear = DateTime.now().year - b.age;
    final avatarUrl = await _uploadAvatar(avatarFile);
    final data = await _repository.createBeneficiary({
      'FullName': b.name,
      'DateOfBirth': '$approxBirthYear-01-01',
      'RelationshipToCustomer': b.relation,
      'GeneralNote': b.condition,
      'CareInstructions': b.notes,
      'DefaultAddressId': b.defaultAddressId,
      'CareLevel': b.careLevel,
      'EmergencyContacts': b.emergencyContacts
          .map((contact) => contact.toJson())
          .toList(growable: false),
      'AvatarUrl': avatarUrl,
    });

    final synced = data == null
        ? null
        : _fromBackend(
            data,
            addressesById: const {},
          );
    await _loadFromBackend();
    return synced;
  }

  Future<void> update(
    String id, {
    String? name,
    int? age,
    String? relation,
    String? condition,
    String? careLevel,
    String? notes,
    required AddressModel defaultAddress,
    List<EmergencyContact>? emergencyContacts,
    XFile? avatarFile,
  }) async {
    final previousState = state;
    BeneficiaryModel? matched;
    for (final beneficiary in state) {
      if (beneficiary.id == id) {
        matched = beneficiary;
        break;
      }
    }
    final current = matched;
    if (current == null) return;
    BeneficiaryModel? updatedItem;
    state = [
      for (final b in state)
        if (b.id == id)
          (() {
            final updated = b.copyWith(
              name: name,
              age: age,
              relation: relation,
              avatarInitial: name
                  ?.trim()
                  .split(RegExp(r'\s+'))
                  .where((part) => part.isNotEmpty)
                  .map((part) => part[0].toUpperCase())
                  .take(3)
                  .join(),
              condition: condition,
              careLevel: careLevel,
              notes: notes,
              address: defaultAddress.fullAddress,
              defaultAddressId: defaultAddress.id,
              emergencyContacts: emergencyContacts,
              avatarPath: avatarFile?.path ?? current.avatarPath,
            );
            updatedItem = updated;
            return updated;
          })()
        else
          b
    ];

    if (updatedItem == null) return;

    try {
      await _syncUpdateToBackend(
        id,
        updatedItem!,
        avatarFile,
        current.avatarPath,
      );
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> _syncUpdateToBackend(
    String id,
    BeneficiaryModel b,
    XFile? avatarFile,
    String? currentAvatarUrl,
  ) async {
    final isGuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
    if (!isGuid) return;

    final approxBirthYear = DateTime.now().year - b.age;
    final uploadedAvatarUrl = await _uploadAvatar(avatarFile);
    final avatarUrl = uploadedAvatarUrl ??
        (_isRemoteUrl(currentAvatarUrl) ? currentAvatarUrl : null);
    await _repository.updateBeneficiary(id, {
      'FullName': b.name,
      'DateOfBirth': '$approxBirthYear-01-01',
      'RelationshipToCustomer': b.relation,
      'GeneralNote': b.condition,
      'CareInstructions': b.notes,
      'DefaultAddressId': b.defaultAddressId,
      'CareLevel': b.careLevel,
      'EmergencyContacts': b.emergencyContacts
          .map((contact) => contact.toJson())
          .toList(growable: false),
      'AvatarUrl': avatarUrl,
    });
    await _loadFromBackend();
  }

  void delete(String id) {
    state = state.where((b) => b.id != id).toList();
    try {
      unawaited(_repository.deleteBeneficiary(id));
    } catch (_) {}
  }

  Future<List<AddressModel>> _readAddresses() async {
    try {
      return await ref.read(addressStoreProvider.future);
    } catch (_) {
      return const [];
    }
  }

  BeneficiaryModel _fromBackend(
    Map<String, dynamic> map, {
    required Map<String, AddressModel> addressesById,
  }) {
    final id = (map['id'] ?? map['Id'])?.toString() ?? '';
    final fullName =
        (map['fullName'] ?? map['FullName']) as String? ?? 'Người thân';
    final dobStr = (map['dateOfBirth'] ?? map['DateOfBirth']) as String?;
    var age = 70;
    if (dobStr != null) {
      final parsedDob = DateTime.tryParse(dobStr);
      if (parsedDob != null) {
        age = DateTime.now().year - parsedDob.year;
      }
    }
    final relation = (map['relationshipToCustomer'] ??
            map['RelationshipToCustomer']) as String? ??
        'Người thân';
    final mobilityNote =
        (map['mobilityNote'] ?? map['MobilityNote']) as String?;
    final generalNote = (map['generalNote'] ?? map['GeneralNote']) as String?;
    final careInstructions =
        (map['careInstructions'] ?? map['CareInstructions']) as String? ?? '';
    final defaultAddressId =
        (map['defaultAddressId'] ?? map['DefaultAddressId'])?.toString();
    final address = defaultAddressId == null
        ? ''
        : addressesById[defaultAddressId]?.fullAddress ?? '';
    final careLevel = (map['careLevel'] ?? map['CareLevel'])?.toString().trim();
    final avatarUrl = (map['avatarUrl'] ?? map['AvatarUrl'])?.toString().trim();
    final emergencyContacts = _readEmergencyContacts(
      map['emergencyContacts'] ?? map['EmergencyContacts'],
    );

    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(3)
        .join();

    return BeneficiaryModel(
      id: id,
      name: fullName,
      age: age,
      relation: relation,
      avatarInitial: initials.isNotEmpty ? initials : 'B',
      condition: generalNote ?? mobilityNote ?? 'Bình thường',
      careLevel:
          careLevel == null || careLevel.isEmpty ? 'Trung bình' : careLevel,
      notes: careInstructions,
      address: address,
      defaultAddressId: defaultAddressId,
      emergencyContacts: emergencyContacts,
      avatarPath: avatarUrl == null || avatarUrl.isEmpty ? null : avatarUrl,
    );
  }

  Future<String?> _uploadAvatar(XFile? avatarFile) async {
    if (avatarFile == null) return null;
    return _repository.uploadAvatar(
      await avatarFile.readAsBytes(),
      avatarFile.name,
    );
  }

  List<EmergencyContact> _readEmergencyContacts(Object? raw) {
    Object? value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => EmergencyContact.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty)
        .toList(growable: false);
  }

  bool _isRemoteUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
