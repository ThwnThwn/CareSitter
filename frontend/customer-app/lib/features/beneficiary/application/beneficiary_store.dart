import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../catalog/application/address_store.dart';
import '../data/beneficiary_model.dart';

export '../data/beneficiary_model.dart';

final beneficiaryStoreProvider =
    NotifierProvider<BeneficiaryStore, List<BeneficiaryModel>>(
  BeneficiaryStore.new,
);

class BeneficiaryStore extends Notifier<List<BeneficiaryModel>> {
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
      final dio = ref.read(dioClientProvider);
      final addresses = await _readAddresses();
      final addressesById = {
        for (final address in addresses) address.id: address
      };
      final resp = await dio.get<List<dynamic>>('/beneficiaries');
      if (resp.data != null) {
        final list = resp.data!
            .whereType<Map<String, dynamic>>()
            .map((item) => _fromBackend(item, addressesById: addressesById))
            .toList();

        state = list;
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
    String? avatarPath,
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
      avatarPath: avatarPath,
    );
    final previousState = state;
    state = [...state, beneficiary];

    try {
      final synced = await _syncAddToBackend(beneficiary);
      return synced ?? beneficiary;
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<BeneficiaryModel?> _syncAddToBackend(BeneficiaryModel b) async {
    final dio = ref.read(dioClientProvider);

    final approxBirthYear = DateTime.now().year - b.age;
    final resp = await dio.post<Map<String, dynamic>>('/beneficiaries', data: {
      'FullName': b.name,
      'DateOfBirth': '$approxBirthYear-01-01',
      'RelationshipToCustomer': b.relation,
      'GeneralNote': b.condition,
      'CareInstructions': b.notes,
      'DefaultAddressId': b.defaultAddressId,
    });

    final synced = resp.data == null
        ? null
        : _fromBackend(
            resp.data!,
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
    String? avatarPath,
  }) async {
    final previousState = state;
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
              avatarPath: avatarPath,
            );
            updatedItem = updated;
            return updated;
          })()
        else
          b
    ];

    if (updatedItem == null) return;

    try {
      await _syncUpdateToBackend(id, updatedItem!);
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }

  Future<void> _syncUpdateToBackend(String id, BeneficiaryModel b) async {
    final isGuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
    if (!isGuid) return;

    final dio = ref.read(dioClientProvider);
    final approxBirthYear = DateTime.now().year - b.age;
    await dio.put('/beneficiaries/$id', data: {
      'FullName': b.name,
      'DateOfBirth': '$approxBirthYear-01-01',
      'RelationshipToCustomer': b.relation,
      'GeneralNote': b.condition,
      'CareInstructions': b.notes,
      'DefaultAddressId': b.defaultAddressId,
    });
    await _loadFromBackend();
  }

  void delete(String id) {
    state = state.where((b) => b.id != id).toList();
    try {
      ref.read(dioClientProvider).delete('/beneficiaries/$id');
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
      careLevel: 'Trung bình',
      notes: careInstructions,
      address: address,
      defaultAddressId: defaultAddressId,
      emergencyContacts: const [],
    );
  }
}
