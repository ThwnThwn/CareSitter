import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import '../../domain/beneficiary_form_rules.dart';
import 'beneficiary_controller.dart';
import 'beneficiary_form_state.dart';
import 'beneficiary_form_result.dart';
export 'beneficiary_form_state.dart';
export 'beneficiary_form_result.dart';

typedef BeneficiarySave = Future<String> Function(
    BeneficiaryFormState state,
    String name,
    DateTime? birthDate,
    String notes,
    List<EmergencyContact> contacts,
    XFile? avatar);

final beneficiaryFormControllerProvider = StateNotifierProvider.autoDispose
    .family<BeneficiaryFormController, BeneficiaryFormState, String?>(
        (ref, id) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final store = ref.read(beneficiaryStoreProvider.notifier);
  late final BeneficiaryFormController controller;
  controller = BeneficiaryFormController(
    initial:
        ref.read(beneficiaryStoreProvider).where((b) => b.id == id).firstOrNull,
    saveRecord: (state, name, birthDate, notes, contacts, avatar) async {
      final address = (await ref.read(addressStoreProvider.future))
          .where((a) => a.id == state.addressId && a.isVerified)
          .firstOrNull;
      if (!controller.mounted) throw StateError('Phiên đã thay đổi.');
      if (address == null) {
        throw StateError('Vui lòng chọn địa chỉ đã xác minh.');
      }
      if (id == null) {
        return (await store.add(
                name: name,
                dateOfBirth: birthDate,
                gender: state.gender,
                relation: state.relation,
                condition: state.conditions.join(', '),
                careLevel: state.careLevel,
                notes: notes,
                defaultAddress: address,
                emergencyContacts: contacts,
                avatarFile: avatar))
            .id;
      }
      await store.update(id,
          name: name.trim(),
          dateOfBirth: birthDate,
          gender: state.gender,
          relation: state.relation,
          condition: state.conditions.join(', '),
          careLevel: state.careLevel,
          notes: notes.trim(),
          defaultAddress: address,
          emergencyContacts: contacts,
          avatarFile: avatar);
      return id;
    },
    editing: id != null,
  );
  ref.listen(
      beneficiaryStoreProvider,
      (_, profiles) =>
          controller.seed(profiles.where((b) => b.id == id).firstOrNull));
  return controller;
});

class BeneficiaryFormController extends StateNotifier<BeneficiaryFormState> {
  BeneficiaryFormController(
      {required this.saveRecord,
      this.editing = false,
      BeneficiaryModel? initial})
      : super(_from(initial));
  final BeneficiarySave saveRecord;
  final bool editing;
  bool _dirty = false;
  int _generation = 0;
  BeneficiaryFormState get value => state;
  static BeneficiaryFormState _from(BeneficiaryModel? b) => b == null
      ? const BeneficiaryFormState()
      : BeneficiaryFormState(
          addressId: b.defaultAddressId,
          gender: b.gender,
          relation: b.relation,
          careLevel: b.careLevel,
          avatarPath: b.avatarPath,
          conditions:
              b.condition.isEmpty ? const [] : List.unmodifiable([b.condition]),
          isSelf: b.isSelf,
          profileFound: true);
  void seed(BeneficiaryModel? b) {
    if (!mounted || _dirty || state.profileFound || b == null) return;
    state = _from(b);
  }

  void _edit(BeneficiaryFormState next) {
    _dirty = true;
    state = next;
  }

  String? get gender => state.gender;
  set gender(String? value) => _edit(state.copy(gender: value));
  String get relation => state.relation;
  set relation(String value) => _edit(state.copy(relation: value));
  String get careLevel => state.careLevel;
  set careLevel(String value) => _edit(state.copy(careLevel: value));
  String? get avatarPath => state.avatarPath;
  set avatarPath(String? value) => _edit(state.copy(avatarPath: value));
  String? get addressId => state.addressId;
  set addressId(String? value) => _edit(state.copy(addressId: value));
  void addCondition(String value) {
    final text = value.trim();
    if (text.isNotEmpty && !state.conditions.contains(text)) {
      _edit(state.copy(conditions: [...state.conditions, text]));
    }
  }

  void removeCondition(String value) => _edit(state.copy(
      conditions: state.conditions.where((s) => s != value).toList()));

  Future<BeneficiaryFormResult> save(
      {required String name,
      required DateTime? birthDate,
      required String notes,
      required List<EmergencyContact> contacts,
      XFile? avatar}) async {
    if (!mounted || state.saving) return const BeneficiaryFormIgnored();
    final contactsError =
        beneficiaryContactsError(contacts.map((c) => c.phone).toList());
    if (contactsError != null) return BeneficiaryFormMessage(contactsError);
    if (state.addressId == null) {
      return const BeneficiaryFormMessage('Vui lòng chọn địa chỉ đã xác minh.');
    }
    final generation = _generation;
    final draft = state;
    state = state.copy(saving: true);
    try {
      final id =
          await saveRecord(draft, name, birthDate, notes, contacts, avatar);
      if (!mounted || generation != _generation) {
        return const BeneficiaryFormIgnored();
      }
      state = state.copy(saving: false);
      return BeneficiaryFormSaved(id);
    } on StateError catch (error) {
      if (!mounted || generation != _generation) {
        return const BeneficiaryFormIgnored();
      }
      state = state.copy(saving: false);
      return BeneficiaryFormMessage(error.message.toString());
    } catch (_) {
      if (!mounted || generation != _generation) {
        return const BeneficiaryFormIgnored();
      }
      state = state.copy(saving: false);
      return BeneficiaryFormMessage(editing
          ? 'Không cập nhật được hồ sơ. Vui lòng thử lại.'
          : 'Không thêm được người thân. Vui lòng thử lại.');
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
