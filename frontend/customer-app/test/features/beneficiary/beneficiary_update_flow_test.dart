import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_detail_screen.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/screens/beneficiary_edit_screen.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _id = '11111111-1111-1111-1111-111111111111';
const _address = AddressModel(
    id: '22222222-2222-2222-2222-222222222222',
    fullAddress: 'Địa chỉ thử nghiệm',
    isVerified: true);
final _seed = <String, dynamic>{
  'Id': _id,
  'FullName': 'Hồ sơ thử nghiệm',
  'DateOfBirth': '1950-12-23',
  'Gender': 'FEMALE',
  'RelationshipToCustomer': 'Mẹ',
  'CareLevel': 'Nhẹ',
  'DefaultAddressId': _address.id,
  'GeneralNote': 'Cần hỗ trợ',
  'Allergies': ['test-allergen'],
  'Medications': ['test-medication'],
  'EmergencyContacts': [
    {'name': 'Liên hệ A', 'phone': '0901234567', 'relationship': 'Con trai'},
    {'name': 'Liên hệ B', 'phone': '0901234568', 'relationship': 'Con gái'},
  ],
};

void main() {
  late _Repository repository;
  late ProviderContainer container;
  setUp(() {
    repository = _Repository();
    container = ProviderContainer(overrides: [
      beneficiaryStoreProvider.overrideWith(_Store.new),
      beneficiaryRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(_Auth.new),
      addressStoreProvider.overrideWith(_Addresses.new),
    ]);
  });
  tearDown(() => container.dispose());

  test(
      'successful update uses the persisted response and does not send stale health data',
      () async {
    final store = container.read(beneficiaryStoreProvider.notifier);
    await store.update(_id,
        name: 'Tên mới',
        dateOfBirth: DateTime(1950, 12, 23),
        gender: 'FEMALE',
        defaultAddress: _address);
    expect(repository.lastRequest,
        {'FullName': 'Tên mới', 'DefaultAddressId': _address.id});
    final saved = container.read(beneficiaryStoreProvider).single;
    expect(saved.name, 'Tên mới');
    expect(saved.dateOfBirth, DateTime(1950, 12, 23));
    expect(saved.allergies, ['updated-on-server']);
  });

  test(
      'create sends exact date and gender and replaces the temporary id with the saved id',
      () async {
    final store = container.read(beneficiaryStoreProvider.notifier);
    final saved = await store.add(
        name: 'Người thân mới',
        dateOfBirth: DateTime(1960, 2, 29),
        gender: 'OTHER',
        relation: 'Khác',
        condition: '',
        careLevel: 'Nhẹ',
        notes: '',
        defaultAddress: _address,
        emergencyContacts: const []);
    expect(repository.lastRequest!['DateOfBirth'], '1960-02-29');
    expect(repository.lastRequest!['Gender'], 'OTHER');
    expect(saved.id, '33333333-3333-3333-3333-333333333333');
    expect(container.read(beneficiaryStoreProvider).last.id, saved.id);
  });

  test(
      'failed update restores the original profile and unknown ids cannot report success',
      () async {
    repository.failUpdate = true;
    final store = container.read(beneficiaryStoreProvider.notifier);
    await expectLater(
        store.update(_id,
            name: 'Tên mới',
            dateOfBirth: null,
            gender: 'MALE',
            defaultAddress: _address),
        throwsStateError);
    final saved = container.read(beneficiaryStoreProvider).single;
    expect(saved.name, _seed['FullName']);
    expect(saved.dateOfBirth, DateTime(1950, 12, 23));
    expect(saved.gender, 'FEMALE');
    repository.lastRequest = null;
    await expectLater(
        store.update('missing',
            dateOfBirth: null, gender: null, defaultAddress: _address),
        throwsStateError);
    expect(repository.lastRequest, isNull);
  });

  testWidgets(
      'editing a name keeps the displayed birth date and gender through save',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/edit', routes: [
      GoRoute(
          path: '/edit',
          builder: (_, __) => const BeneficiaryEditScreen(id: _id)),
      GoRoute(
          path: '/beneficiaries/$_id',
          builder: (_, __) => const Scaffold(body: Text('Đã lưu'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('23/12/1950'), findsOneWidget);
    expect(find.text('Nữ'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Tên đã sửa');
    await tester.tap(find.text('Lưu').first);
    await tester.pumpAndSettle();
    expect(repository.lastRequest,
        {'FullName': 'Tên đã sửa', 'DefaultAddressId': _address.id});
    expect(find.text('Đã lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'an edit opened before loading hydrates when its own profile arrives',
      (tester) async {
    final store = container.read(beneficiaryStoreProvider.notifier) as _Store;
    store.replaceProfiles([]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BeneficiaryEditScreen(id: _id))));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy hồ sơ người thân.'), findsOneWidget);
    store.replaceProfiles([BeneficiaryModel.fromBackend(_seed)]);
    await tester.pumpAndSettle();
    expect(find.text('23/12/1950'), findsOneWidget);
    expect(find.text('Nữ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final edit in [false, true]) {
    testWidgets(
        'missing profile never falls back to another person (edit=$edit)',
        (tester) async {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: edit
                  ? const BeneficiaryEditScreen(id: 'missing')
                  : const BeneficiaryDetailScreen(id: 'missing'))));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy hồ sơ người thân.'), findsOneWidget);
      expect(find.text('Hồ sơ thử nghiệm'), findsNothing);
      expect(repository.lastRequest, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Store extends BeneficiaryStore {
  void replaceProfiles(List<BeneficiaryModel> profiles) => state = profiles;
  @override
  List<BeneficiaryModel> build() => [BeneficiaryModel.fromBackend(_seed)];
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
}

class _Addresses extends AddressStore {
  @override
  Future<List<AddressModel>> build() async => [_address];
}

class _Repository implements BeneficiaryRepository {
  bool failUpdate = false;
  Map<String, dynamic>? lastRequest;
  @override
  Future<Map<String, dynamic>> createBeneficiary(
      Map<String, dynamic> data) async {
    lastRequest = data;
    return {...data, 'Id': '33333333-3333-3333-3333-333333333333'};
  }

  @override
  Future<Map<String, dynamic>> updateBeneficiary(
      String id, Map<String, dynamic> data) async {
    lastRequest = data;
    if (failUpdate) throw StateError('Lỗi thử nghiệm');
    return {
      ..._seed,
      ...data,
      'Allergies': ['updated-on-server']
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
