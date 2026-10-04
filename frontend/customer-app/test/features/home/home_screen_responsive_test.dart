import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/screens/caregiver_list_screen.dart';
import 'package:caresitter_customer/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('home hero cards do not overflow at 320 px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_HomeBookingStore.new),
          caregiverStoreProvider.overrideWith(_HomeCaregiverStore.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ca đang diễn ra hôm nay'), findsOneWidget);
    expect(find.text('11:00 - 15:00 (Cô Lan)'), findsOneWidget);
    expect(find.text('380.000đ'), findsOneWidget);
    expect(find.text('Đang diễn ra'), findsWidgets);
    final bookingCta = tester.widget<Text>(find.text('Đặt lịch ngay'));
    expect(bookingCta.overflow, isNull);
    expect(find.byKey(const Key('home-book-now-cta')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home-hero-banner'))).height,
      352,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home hides the session card when there is no eligible booking',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_EmptyBookingStore.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ca đang diễn ra hôm nay'), findsNothing);
    expect(find.text('Ca sắp diễn ra hôm nay'), findsNothing);
    expect(find.text('Ca sắp tới'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home never presents a cancelled future booking as ongoing',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_CorruptFutureBookingStore.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ca đang diễn ra hôm nay'), findsNothing);
    expect(find.text('Đang diễn ra'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows the nearest real upcoming booking', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_UpcomingBookingStore.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ca sắp tới'), findsOneWidget);
    expect(find.textContaining('(Cô Gần)'), findsOneWidget);
    expect(find.textContaining('(Cô Xa)'), findsNothing);
    expect(find.textContaining('(Ca đã xong)'), findsNothing);
    expect(find.text('Sắp diễn ra'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home search submits its query to the caregiver results route',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/caregivers',
          builder: (_, state) => CaregiverListScreen(
            initialQuery: state.uri.queryParameters['q'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_HomeBookingStore.new),
          caregiverStoreProvider.overrideWith(_HomeCaregiverStore.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(
      tester.getSize(find.byKey(const Key('home-hero-banner'))).height,
      320,
    );
    expect(tester.takeException(), isNull);

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Bình Thạnh');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final resultsSearchField = tester.widget<TextField>(find.byType(TextField));
    expect(resultsSearchField.controller?.text, 'Bình Thạnh');
    expect(find.text('Cô Lan'), findsOneWidget);
    expect(find.text('Chú Minh'), findsNothing);
    expect(find.text('An tâm tuyệt đối với CareSitter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home supports enlarged text at 320 px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_HomeBookingStore.new),
          caregiverStoreProvider.overrideWith(_HomeCaregiverStore.new),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Đặt lịch ngay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _HomeBookingStore extends BookingStore {
  @override
  List<BookingModel> build() {
    final now = DateTime.now();
    return [
      BookingModel(
        id: 'booking-today',
        beneficiaryId: 'beneficiary',
        caregiverId: 'caregiver',
        addressId: 'address',
        serviceTypeId: 'service',
        scheduledStart: DateTime(now.year, now.month, now.day, 11),
        scheduledEnd: DateTime(now.year, now.month, now.day, 15),
        actualStart: now.subtract(const Duration(minutes: 5)),
        status: 'in_progress',
        escrowAmount: 380000,
        platformFeeAmount: 0,
        createdAt: now,
        updatedAt: now,
        caregiverName: 'Cô Lan',
      ),
    ];
  }
}

class _EmptyBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => const [];
}

class _CorruptFutureBookingStore extends BookingStore {
  @override
  List<BookingModel> build() {
    final now = DateTime.now();
    return [
      BookingModel(
        id: 'future-cancelled-booking',
        beneficiaryId: 'beneficiary',
        addressId: 'address',
        serviceTypeId: 'service',
        scheduledStart: now.add(const Duration(days: 8)),
        scheduledEnd: now.add(const Duration(days: 8, hours: 4)),
        status: 'in_progress',
        escrowAmount: 380000,
        platformFeeAmount: 57000,
        cancelledAt: now.subtract(const Duration(days: 1)),
        cancelReason: 'AUTO_EXPIRED_PAYMENT_TIMEOUT',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

class _UpcomingBookingStore extends BookingStore {
  @override
  List<BookingModel> build() {
    final now = DateTime.now();

    BookingModel booking({
      required String id,
      required String status,
      required DateTime start,
      required String caregiverName,
    }) {
      return BookingModel(
        id: id,
        beneficiaryId: 'beneficiary',
        caregiverId: 'caregiver-$id',
        addressId: 'address',
        serviceTypeId: 'service',
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 4)),
        status: status,
        escrowAmount: 380000,
        platformFeeAmount: 0,
        createdAt: now,
        updatedAt: now,
        caregiverName: caregiverName,
      );
    }

    return [
      booking(
        id: 'completed',
        status: 'completed',
        start: now.subtract(const Duration(hours: 6)),
        caregiverName: 'Ca đã xong',
      ),
      booking(
        id: 'far',
        status: 'confirmed',
        start: now.add(const Duration(days: 2)),
        caregiverName: 'Cô Xa',
      ),
      booking(
        id: 'near',
        status: 'caregiver_accepted',
        start: now.add(const Duration(days: 1)),
        caregiverName: 'Cô Gần',
      ),
    ];
  }
}

class _HomeCaregiverStore extends CaregiverStore {
  @override
  Future<List<CaregiverModel>> build() async => const [
        CaregiverModel(
          id: 'caregiver-lan',
          userId: 'user-lan',
          fullName: 'Cô Lan',
          ratingAvg: 4.9,
          ratingCount: 20,
          availabilityStatus: 'ONLINE',
          skills: ['Chăm sóc người cao tuổi'],
          serviceCity: 'Hồ Chí Minh',
          serviceDistrict: 'Bình Thạnh',
        ),
        CaregiverModel(
          id: 'caregiver-minh',
          userId: 'user-minh',
          fullName: 'Chú Minh',
          ratingAvg: 4.8,
          ratingCount: 18,
          availabilityStatus: 'ONLINE',
          skills: ['Vật lý trị liệu'],
          serviceCity: 'Hồ Chí Minh',
          serviceDistrict: 'Quận 1',
        ),
      ];
}
