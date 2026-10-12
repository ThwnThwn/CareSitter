import 'dart:async';
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
  int _sessionGeneration = 0;
  int _loadGeneration = 0;
  String? get _userId => ref.read(authStateProvider).value?.userId;

  void acceptSaved(BeneficiaryModel value) {
    if (_userId == null) return;
    _loadGeneration++;
    state = [...state.where((b) => b.id != value.id), value];
  }

  BeneficiaryRepository get _repository =>
      ref.read(beneficiaryRepositoryProvider);

  @override
  List<BeneficiaryModel> build() {
    // Lắng nghe đăng nhập để tải dữ liệu người thân của user thật
    ref.listen(authStateProvider, (prev, next) {
      if (prev?.value?.userId != next.value?.userId) {
        _sessionGeneration++;
        state = const [];
      }
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
    final session = _sessionGeneration;
    final userId = _userId;
    final generation = ++_loadGeneration;
    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;

    try {
      final addresses = await _readAddresses();
      final addressesById = {
        for (final address in addresses) address.id: address.fullAddress
      };
      final data = await _repository.getBeneficiaries();
      if (session != _sessionGeneration ||
          userId != _userId ||
          generation != _loadGeneration) {
        return;
      }
      if (data.isNotEmpty) {
        final list = data
            .map((item) => BeneficiaryModel.fromBackend(item,
                addressesById: addressesById))
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
    required DateTime? dateOfBirth,
    required String? gender,
    required String relation,
    required String condition,
    required String careLevel,
    required String notes,
    required AddressModel defaultAddress,
    required List<EmergencyContact> emergencyContacts,
    XFile? avatarFile,
  }) async {
    final session = _sessionGeneration;
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
      dateOfBirth: dateOfBirth,
      gender: gender,
      relation: relation,
      avatarInitial: initials.isNotEmpty ? initials : 'B',
      condition: condition.trim(),
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
      return synced;
    } catch (_) {
      if (session == _sessionGeneration) state = previousState;
      rethrow;
    }
  }

  Future<BeneficiaryModel> _syncAddToBackend(
    BeneficiaryModel b,
    XFile? avatarFile,
  ) async {
    final session = _sessionGeneration;
    final avatarUrl = await _uploadAvatar(avatarFile);
    if (session != _sessionGeneration) throw StateError('Phiên đã thay đổi.');
    final data = await _repository.createBeneficiary(
      b.toProfileRequest(avatarUrl: avatarUrl),
    );
    if (session != _sessionGeneration) throw StateError('Phiên đã thay đổi.');

    final synced = BeneficiaryModel.fromBackend(data, addressesById: {
      if (b.defaultAddressId != null) b.defaultAddressId!: b.address
    });
    state = [
      for (final item in state)
        if (item.id == b.id) synced else item
    ];
    await _loadFromBackend();
    return synced;
  }

  Future<void> update(
    String id, {
    String? name,
    required DateTime? dateOfBirth,
    required String? gender,
    String? relation,
    String? condition,
    String? careLevel,
    String? notes,
    required AddressModel defaultAddress,
    List<EmergencyContact>? emergencyContacts,
    XFile? avatarFile,
  }) async {
    final session = _sessionGeneration;
    final previousState = state;
    BeneficiaryModel? matched;
    for (final beneficiary in state) {
      if (beneficiary.id == id) {
        matched = beneficiary;
        break;
      }
    }
    final current = matched;
    if (current == null) throw StateError('Không tìm thấy hồ sơ người thân.');
    BeneficiaryModel? updatedItem;
    state = [
      for (final b in state)
        if (b.id == id)
          (() {
            final updated = b.copyWith(
              name: name,
              dateOfBirth: dateOfBirth,
              gender: gender,
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
        current,
      );
    } catch (_) {
      if (session == _sessionGeneration) state = previousState;
      rethrow;
    }
  }

  Future<void> _syncUpdateToBackend(
    String id,
    BeneficiaryModel b,
    XFile? avatarFile,
    BeneficiaryModel previous,
  ) async {
    final session = _sessionGeneration;
    final isGuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(id);
    if (!isGuid) throw StateError('Hồ sơ chưa được lưu trên máy chủ.');

    final uploadedAvatarUrl = await _uploadAvatar(avatarFile);
    if (session != _sessionGeneration) throw StateError('Phiên đã thay đổi.');
    final avatarUrl = uploadedAvatarUrl ??
        (_isRemoteUrl(previous.avatarPath) ? previous.avatarPath : null);
    final data = await _repository.updateBeneficiary(
      id,
      b.toProfileRequest(previous: previous, avatarUrl: avatarUrl),
    );
    if (session != _sessionGeneration) throw StateError('Phiên đã thay đổi.');
    final synced = BeneficiaryModel.fromBackend(data, addressesById: {
      if (b.defaultAddressId != null) b.defaultAddressId!: b.address
    });
    state = [
      for (final item in state)
        if (item.id == id) synced else item
    ];
    await _loadFromBackend();
  }

  Future<BeneficiaryModel> fetchProfile(String id) =>
      _repository.getBeneficiary(id);

  Future<void> delete(String id) async {
    if (state.any((b) => b.id == id && b.isSelf)) {
      throw StateError(
          'Vui lòng sửa thông tin chăm sóc của tôi thay vì xóa hồ sơ.');
    }
    final session = _sessionGeneration;
    await _repository.deleteBeneficiary(id);
    if (session == _sessionGeneration) {
      state = state.where((b) => b.id != id).toList();
    }
  }

  Future<List<AddressModel>> _readAddresses() async {
    try {
      return await ref.read(addressStoreProvider.future);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _uploadAvatar(XFile? avatarFile) async {
    if (avatarFile == null) return null;
    return _repository.uploadAvatar(
      await avatarFile.readAsBytes(),
      avatarFile.name,
    );
  }

  bool _isRemoteUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
