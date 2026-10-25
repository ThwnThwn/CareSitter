import 'package:caresitter_customer/core/api/dio_client.dart' show DioClient;
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_submit_result.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/self_recipient_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_wizard_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/self_recipient_form.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/settings/data/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

const _contacts = [
  EmergencyContact(name: 'Liên hệ A', phone: '0901234567', relationship: 'Bạn'),
  EmergencyContact(name: 'Liên hệ B', phone: '0912345678', relationship: 'Chị')
];
const _profile = BeneficiaryModel(
    id: 'self-id',
    name: 'Nguyễn An',
    isSelf: true,
    relation: 'Bản thân',
    avatarInitial: 'NA',
    condition: '',
    careLevel: '',
    notes: '',
    address: '',
    emergencyContacts: _contacts,
    defaultAddressId: 'address');
final _draft = BookingDraft(
    beneficiaryId: 'self-id',
    serviceTypeId: 'service',
    addressId: 'address',
    scheduledStart: DateTime(2027, 1, 1, 9),
    scheduledEnd: DateTime(2027, 1, 1, 11),
    isSystemMatched: false,
    caregiverId: 'caregiver');

Future<void> _loaded(SelfRecipientController controller) async {
  for (var i = 0; i < 20 && controller.state.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _flushWizard() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _People people;
  late _Account account;
  setUp(() {
    people = _People();
    account = _Account();
  });

  test(
      'first selection reads account without creating and keeps unknown health',
      () async {
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    final selected = controller.state.requireValue;
    expect(selected.kind, SelfRecipientKind.draft);
    expect(selected.profile.name, 'Từ tài khoản');
    expect(selected.profile.id, isEmpty);
    expect(selected.profile.dateOfBirth, DateTime(1990, 12, 23));
    expect(selected.profile.gender, 'FEMALE');
    expect(selected.profile.healthHistory, isNull);
    expect(selected.profile.medications, isNull);
    expect(people.creates, 0);
    expect(selected.isComplete, isFalse);
  });

  test('existing self is authoritative and never fetches account defaults',
      () async {
    people.self = _profile;
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    expect(controller.state.requireValue.profile.id, 'self-id');
    expect(account.reads, 0);
    await controller.resolve('booking-address');
    expect(people.creates, 0);
    expect(people.self!.defaultAddressId, 'address');
  });

  test('health change on another device requires review before booking',
      () async {
    people.self = _profile;
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    people.self = BeneficiaryModel.fromBackend({
      'Id': 'self-id',
      'IsSelf': true,
      'FullName': 'Nguyễn An',
      'RelationshipToCustomer': 'Bản thân',
      'DefaultAddressId': 'address',
      'EmergencyContacts':
          _contacts.map((contact) => contact.toJson()).toList(),
      'Allergies': ['Đậu phộng'],
    });
    final saved = await controller.resolve('address');
    expect(saved.needsReview, isTrue);
    expect(saved.profile.allergies, ['Đậu phộng']);
  });

  test('read error is not absence and cannot create', () async {
    people.failGet = true;
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    expect(controller.state.hasError, isTrue);
    expect(account.reads, 0);
    expect(people.creates, 0);
    people.failGet = false;
    await controller.load();
    expect(controller.state.hasValue, isTrue);
  });

  test('missing account name stays empty until customer enters a real name',
      () async {
    account.name = null;
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    expect(controller.state.requireValue.profile.name, isEmpty);
    expect(controller.state.requireValue.isComplete, isFalse);
  });

  test('final confirmation creates once; booking retry uses persisted ID',
      () async {
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    controller.updateDraft(controller.state.requireValue.profile
        .copyWith(emergencyContacts: _contacts));
    final saved = await controller.resolve('verified-address');
    expect(saved.needsReview, isFalse);
    expect(saved.profile.id, 'self-id');
    expect(people.lastRequest!['DefaultAddressId'], 'verified-address');
    expect(people.lastRequest!.containsKey('HealthHistory'), isFalse);
    expect(people.lastRequest!.containsKey('RelationshipToCustomer'), isFalse);
    expect(people.lastRequest!['DateOfBirth'], '1990-12-23');
    await controller.resolve('another-booking-address');
    expect(people.creates, 1);
  });

  test(
      'simultaneous creation returns saved profile for review, never overwrites it',
      () async {
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    controller.updateDraft(controller.state.requireValue.profile
        .copyWith(emergencyContacts: _contacts));
    people.self = _profile;
    final saved = await controller.resolve('address');
    expect(saved.needsReview, isTrue);
    expect(controller.state.requireValue.profile.name, 'Nguyễn An');
  });

  test('timeout resolving self verifies with GET and keeps ID for review',
      () async {
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    controller.updateDraft(controller.state.requireValue.profile
        .copyWith(emergencyContacts: _contacts));
    people.timeoutCreate = true;
    final saved = await controller.resolve('address');
    expect(saved.needsReview, isTrue);
    expect(saved.profile.id, 'self-id');
    expect(people.creates, 1);
  });

  test('link selection has no write until confirmation and retains same ID',
      () async {
    final controller = SelfRecipientController(people, account, 'customer');
    addTearDown(controller.dispose);
    await _loaded(controller);
    controller.selectLink(_profile);
    expect(people.links, 0);
    expect((await controller.resolve('address')).profile.id, _profile.id);
    expect(people.links, 1);
    expect(people.creates, 0);
  });

  test('contacts normalize phone prefixes before detecting duplicates', () {
    final same = _profile.copyWith(emergencyContacts: [
      _contacts.first,
      const EmergencyContact(
          name: 'B', phone: '+84 901234567', relationship: '')
    ]);
    expect(SelfRecipient(SelfRecipientKind.draft, same).isComplete, isFalse);
  });

  test('late response after session disposal cannot continue the flow',
      () async {
    people.waitForSelf = Completer<BeneficiaryModel?>();
    final controller = SelfRecipientController(people, account, 'old-account');
    controller.dispose();
    people.waitForSelf!.complete(_profile);
    await Future<void>.delayed(Duration.zero);
    expect(account.reads, 0);
    expect(people.creates, 0);
  });

  test('caregiver failure keeps created booking in store', () async {
    final repository = _Bookings()..failSelection = true;
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      bookingStoreProvider.overrideWith(_BookingStore.new),
      bookingRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await expectLater(
        container.read(bookingStoreProvider.notifier).createBooking(_draft),
        throwsA(isA<BookingCreatedException>()));
    expect(container.read(bookingStoreProvider).single.id, 'created-booking');
    expect(repository.creates, 1);
    expect(repository.selections, 1);
  });

  test('booking post timeout never proceeds to caregiver selection or retries',
      () async {
    final repository = _Bookings()..timeoutCreate = true;
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      bookingStoreProvider.overrideWith(_BookingStore.new),
      bookingRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await expectLater(
        container.read(bookingStoreProvider.notifier).createBooking(_draft),
        throwsA(isA<BookingOutcomeUnknown>()));
    expect(repository.creates, 1);
    expect(repository.selections, 0);
  });

  test(
      'wizard controller guards concurrent submission and carries a stable operation key',
      () async {
    final bookings = _Bookings()..pendingCreate = Completer<BookingModel>();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      beneficiaryRepositoryProvider.overrideWithValue(people),
      profileRepositoryProvider.overrideWithValue(account),
      serviceStoreProvider.overrideWith(_Services.new),
      addressStoreProvider.overrideWith(_Addresses.new),
      caregiverStoreProvider.overrideWith(_Caregivers.new),
      beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
      bookingStoreProvider.overrideWith(_BookingStore.new),
      bookingRepositoryProvider.overrideWithValue(bookings),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    const args = (
      serviceId: 'service',
      beneficiaryId: null,
      caregiverId: null,
    );
    final sub = container.listen(bookingWizardProvider(args), (_, __) {});
    addTearDown(sub.close);
    await container.read(serviceStoreProvider.future);
    await container.read(addressStoreProvider.future);
    await _flushWizard();
    final self = container.read(selfRecipientProvider.notifier);
    self.updateDraft(
        self.state.requireValue.profile.copyWith(emergencyContacts: _contacts));
    final flow = container.read(bookingWizardProvider(args).notifier);
    flow.forSelf(true);
    flow.next();
    flow.selectDate(DateTime.now().add(const Duration(days: 1)));
    flow.selectTime(480);
    flow.selectAddress('address');
    flow.next();
    flow.next();
    flow.setConsent(true);
    flow.next();
    expect(container.read(bookingWizardProvider(args)).step, 5);
    final first = flow.submit();
    await _loaded(container.read(selfRecipientProvider.notifier));
    expect(await flow.submit(), isA<BookingSubmitIgnored>());
    expect(bookings.creates, 1);
    expect(bookings.lastDraft!.idempotencyKey, isNotEmpty);
    bookings.pendingCreate!
        .complete(BookingModel.fromJson({'id': 'created-booking'}));
    expect(await first, isA<BookingSubmitted>());
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('self form fits width=$width scale=$scale with keyboard',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        BeneficiaryModel? changed;
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 844),
                        textScaler: TextScaler.linear(scale),
                        viewInsets: const EdgeInsets.only(bottom: 260)),
                    child: Scaffold(
                        body: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SelfRecipientForm(
                                initial: _profile,
                                onChanged: (value) => changed = value,
                                onDateValidityChanged: (_) {})))))));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextFormField).first, 'Tên xác nhận');
        await tester.pumpAndSettle();
        expect(changed!.name, 'Tên xác nhận');
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -2200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'wizard selecting self does not create; changing branch retains draft',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      beneficiaryRepositoryProvider.overrideWithValue(people),
      profileRepositoryProvider.overrideWithValue(account),
      serviceStoreProvider.overrideWith(_Services.new),
      addressStoreProvider.overrideWith(_Addresses.new)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(
                key: boundaryKey,
                child:
                    const BookingWizardScreen(initialServiceId: 'service')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Từ tài khoản'), findsOneWidget);
    expect(people.creates, 0);
    await tester.enterText(find.byType(TextFormField).first, 'Draft của tôi');
    await tester.tap(find.text('Người thân'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Draft của tôi'), findsOneWidget);
    expect(people.creates, 0);
    expect(tester.takeException(), isNull);
    if (Platform.environment['CARESITTER_CAPTURE_SELF_UI'] == '1') {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../../plan/kiem-thu/self-booking-390.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
  });

  testWidgets(
      'complete wizard resolves self only at final confirmation and books its real ID',
      (tester) async {
    final bookings = _Bookings();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      beneficiaryRepositoryProvider.overrideWithValue(people),
      profileRepositoryProvider.overrideWithValue(account),
      serviceStoreProvider.overrideWith(_Services.new),
      addressStoreProvider.overrideWith(_Addresses.new),
      caregiverStoreProvider.overrideWith(_Caregivers.new),
      beneficiaryStoreProvider.overrideWith(_Beneficiaries.new),
      bookingStoreProvider.overrideWith(_BookingStore.new),
      bookingRepositoryProvider.overrideWithValue(bookings)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final router = GoRouter(initialLocation: '/wizard', routes: [
      GoRoute(
          path: '/wizard',
          builder: (_, __) =>
              const BookingWizardScreen(initialServiceId: 'service')),
      GoRoute(
          path: '/bookings/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Đã mở ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi'));
    await tester.pumpAndSettle();
    final controller = container.read(selfRecipientProvider.notifier);
    controller.updateDraft(controller.state.requireValue.profile
        .copyWith(emergencyContacts: _contacts, defaultAddressId: 'address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog), matching: find.text('15')));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn giờ bắt đầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    final consent = find.textContaining('Tôi đã đọc, hiểu và đồng ý');
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    expect(people.creates, 0);
    expect(bookings.creates, 0);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận đặt lịch'));
    await tester.pumpAndSettle();
    expect(people.creates, 1);
    expect(bookings.creates, 1);
    expect(bookings.lastDraft!.beneficiaryId, 'self-id');
    expect(find.text('Đã mở created-booking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final initialId in ['self-id', 'missing']) {
    testWidgets(
        'initial recipient resolves exact record ($initialId) at large text',
        (tester) async {
      people.self = _profile;
      people.records = [
        {
          'id': 'self-id',
          'isSelf': true,
          'fullName': 'Nguyễn An',
          'emergencyContacts': _contacts.map((c) => c.toJson()).toList()
        },
        {'id': 'relative', 'fullName': 'Người thân khác'}
      ];
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith(_Auth.new),
        beneficiaryRepositoryProvider.overrideWithValue(people),
        profileRepositoryProvider.overrideWithValue(account),
        serviceStoreProvider.overrideWith(_Services.new),
        addressStoreProvider.overrideWith(_Addresses.new)
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      final sub = container.listen(bookingRecipientsProvider, (_, __) {});
      addTearDown(sub.close);
      await container.read(bookingRecipientsProvider.future);
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                  data: const MediaQueryData(
                      size: Size(320, 844), textScaler: TextScaler.linear(2)),
                  child: BookingWizardScreen(
                      initialServiceId: 'service',
                      initialBeneficiaryId: initialId)))));
      await tester.pumpAndSettle();
      if (initialId == 'self-id') {
        expect(find.text('Tôi — Nguyễn An'), findsOneWidget);
        expect(find.text('Người thân khác'), findsNothing);
      } else {
        final button = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Tiếp theo'));
        expect(button.onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
      expect(people.creates, 0);
    });
  }
}

class _People extends BeneficiaryRepository {
  _People() : super(_UnusedPeopleClient());
  BeneficiaryModel? self;
  bool failGet = false, timeoutCreate = false;
  int creates = 0, links = 0;
  Map<String, dynamic>? lastRequest;
  List<Map<String, dynamic>> records = [];
  Completer<BeneficiaryModel?>? waitForSelf;
  @override
  Future<BeneficiaryModel?> getSelf() async {
    if (waitForSelf != null) return waitForSelf!.future;
    if (failGet) throw StateError('Read failed');
    return self;
  }

  @override
  Future<BeneficiaryModel> getBeneficiary(String id) async => self!;
  @override
  Future<List<Map<String, dynamic>>> getBeneficiaries() async => records;
  @override
  Future<({BeneficiaryModel beneficiary, bool created})> createSelf(
      Map<String, dynamic> data) async {
    creates++;
    lastRequest = data;
    final created = self == null;
    self ??= BeneficiaryModel.fromBackend({
      ...data,
      'Id': 'self-id',
      'IsSelf': true,
      'RelationshipToCustomer': 'Bản thân'
    });
    if (timeoutCreate) {
      throw const AppApiException(message: 'Mất response');
    }
    return (beneficiary: self!, created: created);
  }

  @override
  Future<BeneficiaryModel> linkSelf(String id) async {
    links++;
    self = _profile;
    return self!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account implements ProfileRepository {
  int reads = 0;
  String? name = 'Từ tài khoản';
  @override
  Future<Map<String, dynamic>> getFreshProfile() async {
    reads++;
    return {
      'fullName': name,
      'dateOfBirth': '1990-12-23',
      'gender': 'FEMALE',
      'phone': '0901234567'
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
}

class _BookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [];
}

class _Bookings implements BookingRepository {
  int creates = 0, selections = 0;
  bool failSelection = false, timeoutCreate = false;
  BookingDraft? lastDraft;
  Completer<BookingModel>? pendingCreate;
  @override
  Future<BookingModel> createBooking(BookingDraft draft) async {
    creates++;
    lastDraft = draft;
    if (pendingCreate != null) return pendingCreate!.future;
    if (timeoutCreate) {
      throw const AppApiException(message: 'Mất response');
    }
    return BookingModel.fromJson({
      'id': 'created-booking',
      'beneficiaryId': draft.beneficiaryId,
      'scheduledStart': draft.scheduledStart.toIso8601String(),
      'scheduledEnd': draft.scheduledEnd.toIso8601String()
    });
  }

  @override
  Future<BookingModel> selectCaregiver(String id,
      {required String caregiverId}) async {
    selections++;
    throw StateError('Selection failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Services extends ServiceStore {
  @override
  Future<List<ServiceModel>> build() async => [
        const ServiceModel(
            id: 'service',
            code: 'TEST',
            name: 'Chăm sóc',
            defaultDurationMinutes: 120)
      ];
}

class _Addresses extends AddressStore {
  @override
  Future<List<AddressModel>> build() async => [
        const AddressModel(
            id: 'address', fullAddress: 'Địa chỉ thử nghiệm', isVerified: true)
      ];
}

class _Caregivers extends CaregiverStore {
  @override
  Future<List<CaregiverModel>> build() async => [];
}

class _Beneficiaries extends BeneficiaryStore {
  @override
  List<BeneficiaryModel> build() => [];
}

class _UnusedPeopleClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
