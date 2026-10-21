import 'dart:async';

import 'package:caresitter_customer/app/screens/nutrition_entry_screen.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/beneficiary_model.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart'
    show BeneficiaryStore, beneficiaryStoreProvider;
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_load_state_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows profiles without waiting for addresses', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        beneficiaryRepositoryProvider.overrideWithValue(
          _ImmediateBeneficiaryRepository(),
        ),
        addressStoreProvider.overrideWith(_PendingAddresses.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NutritionEntryScreen(),
        ),
      ),
    );
    await _flush(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Trần Thị Loan'), findsOneWidget);
  });

  testWidgets('opens the existing nutrition route for the selected profile',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/nutrition',
      routes: [
        GoRoute(
          path: '/nutrition',
          builder: (_, __) => const NutritionEntryScreen(),
        ),
        GoRoute(
          path: '/beneficiaries/:id/nutrition',
          builder: (_, state) => Scaffold(
            body: Text('nutrition:${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/beneficiaries/create',
          builder: (_, __) => const SizedBox(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
          beneficiaryLoadStateProvider.overrideWith(_LoadedState.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('nutrition-beneficiary-loan')),
    );
    await tester.pumpAndSettle();

    expect(find.text('nutrition:loan'), findsOneWidget);
  });
}

Future<void> _flush(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump();
  }
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}

class _PendingAddresses extends AddressStore {
  @override
  Future<List<AddressModel>> build() => Completer<List<AddressModel>>().future;
}

class _ImmediateBeneficiaryRepository implements BeneficiaryRepository {
  @override
  Future<List<Map<String, dynamic>>> getBeneficiaries() async => [
        {
          'Id': 'loan',
          'FullName': 'Trần Thị Loan',
          'RelationshipToCustomer': 'Mẹ',
        }
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Beneficiaries extends BeneficiaryStore {
  @override
  List<BeneficiaryModel> build() => [
        BeneficiaryModel(
          id: 'loan',
          name: 'Trần Thị Loan',
          dateOfBirth: DateTime(1956, 1, 1),
          relation: 'Mẹ',
          avatarInitial: 'TL',
          condition: '',
          careLevel: '',
          notes: '',
          address: '',
        ),
      ];
}

class _LoadedState extends BeneficiaryLoadStateController {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}
