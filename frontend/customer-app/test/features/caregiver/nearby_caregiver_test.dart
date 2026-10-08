import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/repositories/caregiver_repository.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/screens/caregiver_list_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

const addressA = AddressModel(
    id: 'a',
    fullAddress: 'Địa chỉ chăm sóc A',
    latitude: 10,
    longitude: 106,
    isVerified: true);
const addressB = AddressModel(
    id: 'b',
    fullAddress: 'Địa chỉ chăm sóc B',
    latitude: 21,
    longitude: 105,
    isVerified: true);

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
  void signOut() => state = const AsyncData(AuthState(isAuthenticated: false));
}

class _Addresses extends AddressStore {
  final List<AddressModel> initial;
  _Addresses(this.initial);
  @override
  Future<List<AddressModel>> build() async => initial;
}

class _Profile extends ProfileStore {
  _Profile(super.ref) {
    state = state.copyWith(defaultAddressId: 'a');
  }
}

class _Client implements DioClient {
  final queries = <Map<String, dynamic>>[];
  final paths = <String>[];
  final pending = <Completer<Map<String, dynamic>>>[];
  final bool controlled;
  _Client({this.controlled = false});
  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    Map<String, dynamic> result;
    if (path == '/caregivers') {
      queries.add(Map.of(query ?? {}));
      if (controlled) {
        final request = Completer<Map<String, dynamic>>();
        pending.add(request);
        result = await request.future;
      } else {
        result = {
          'items': [
            {
              'id': 'nearby',
              'userId': 'caregiver',
              'fullName': 'Cô Gần',
              'availabilityStatus': 'ONLINE',
              'distanceMeters': 2100
            }
          ]
        };
      }
    } else if (path.startsWith('/caregivers/')) {
      result = {
        'id': path.split('/').last,
        'userId': 'caregiver',
        'fullName': 'Hồ sơ theo ID'
      };
    } else {
      result = {'items': []};
    }
    return Response<T>(
        data: result as T, requestOptions: RequestOptions(path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides(_Client client, List<AddressModel> addresses) => [
      dioClientProvider.overrideWithValue(client),
      authStateProvider.overrideWith(_Auth.new),
      addressStoreProvider.overrideWith(() => _Addresses(addresses)),
      profileStoreProvider.overrideWith((ref) => _Profile(ref)),
    ];

Future<ProviderContainer> _containerFor(
    _Client client, List<AddressModel> addresses) async {
  final container = ProviderContainer(overrides: _overrides(client, addresses));
  await container.read(authStateProvider.future);
  return container;
}

void main() {
  test(
      'uses verified default address and sends coordinates with returned distance',
      () async {
    final client = _Client();
    final container = await _containerFor(client, [addressB, addressA]);
    addTearDown(container.dispose);
    final result = await container.read(nearbyCaregiversProvider.future);
    expect(client.queries.single['lat'], 10);
    expect(client.queries.single['lng'], 106);
    expect(result.single.distanceMeters, 2100);
    expect(result.single.distanceLabel, '2,1 km');
  });

  test(
      'missing or invalid verified coordinates never fetch an unfiltered nearby list',
      () async {
    final client = _Client();
    final container = await _containerFor(client, [
      const AddressModel(
          id: 'legacy',
          fullAddress: 'Chưa xác minh',
          latitude: 10,
          longitude: 106),
      const AddressModel(
          id: 'bad',
          fullAddress: 'Tọa độ sai',
          latitude: 100,
          longitude: 106,
          isVerified: true),
      const AddressModel(
          id: 'missing', fullAddress: 'Thiếu tọa độ', isVerified: true),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(nearbyCaregiversProvider.future), isEmpty);
    expect(client.queries, isEmpty);
  });

  test(
      'selection overrides default and deleted selection cannot fall back to the global directory',
      () async {
    final client = _Client();
    final container = await _containerFor(client, [addressA, addressB]);
    addTearDown(container.dispose);
    container.read(caregiverSearchAddressIdProvider.notifier).state = 'b';
    await container.read(nearbyCaregiversProvider.future);
    expect(client.queries.last['lat'], 21);
    container.read(caregiverSearchAddressIdProvider.notifier).state = 'deleted';
    expect(await container.read(nearbyCaregiversProvider.future), isEmpty);
    expect(client.queries.length, 1);
  });

  test(
      'old address response cannot replace results for the newly selected address',
      () async {
    final client = _Client(controlled: true);
    final container = await _containerFor(client, [addressA, addressB]);
    addTearDown(container.dispose);
    final subscription = container.listen(nearbyCaregiversProvider, (_, __) {});
    addTearDown(subscription.close);
    final first = container.read(nearbyCaregiversProvider.future);
    await Future<void>.delayed(Duration.zero);
    container.read(caregiverSearchAddressIdProvider.notifier).state = 'b';
    final second = container.read(nearbyCaregiversProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(client.pending.length, 2);
    client.pending[1].complete({
      'items': [
        {'id': 'new-address'}
      ]
    });
    expect((await second).single.id, 'new-address');
    client.pending[0].complete({
      'items': [
        {'id': 'old-address'}
      ]
    });
    await first;
    expect(container.read(nearbyCaregiversProvider).valueOrNull!.single.id,
        'new-address');
  });

  test('changing account clears selected address', () async {
    final container = await _containerFor(_Client(), [addressA]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(caregiverSearchAddressIdProvider, (_, __) {});
    addTearDown(subscription.close);
    container.read(caregiverSearchAddressIdProvider.notifier).state = 'b';
    (container.read(authStateProvider.notifier) as _Auth).signOut();
    expect(container.read(caregiverSearchAddressIdProvider), isNull);
  });

  test('partial or nonfinite coordinates are rejected before a request',
      () async {
    final client = _Client();
    final repository = CaregiverRepository(client);
    await expectLater(
        repository.getCaregivers(latitude: 10), throwsArgumentError);
    await expectLater(
        repository.getCaregivers(latitude: double.nan, longitude: 106),
        throwsArgumentError);
    expect(client.queries, isEmpty);
  });

  test('detail is loaded by ID independently of nearby pagination', () async {
    final client = _Client();
    final container = await _containerFor(client, []);
    addTearDown(container.dispose);
    final caregiver =
        await container.read(caregiverDetailProvider('outside-page').future);
    expect(caregiver!.id, 'outside-page');
    expect(client.paths, ['/caregivers/outside-page']);
  });

  testWidgets(
      'location and distance fit narrow large-text layouts and selecting a different address reloads coordinates',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final client = _Client();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const CaregiverListScreen()),
      GoRoute(
          path: '/settings/addresses',
          builder: (context, _) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () => context.pop('b'),
                      child: const Text('Chọn địa chỉ B'))))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: _overrides(client, [addressA, addressB]),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ chăm sóc A'), findsOneWidget);
    expect(find.textContaining('2,1 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('caregiver-location-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn địa chỉ B'));
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ chăm sóc B'), findsOneWidget);
    expect(client.queries.last['lat'], 21);
    expect(tester.takeException(), isNull);
  });
}
