import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
  });

  const scenarios = [
    _Scenario('confirmed', 'Chờ ghép CSV',
        caregiverId: null, expectWaiting: true),
    _Scenario('confirmed', 'Đã xác nhận'),
    _Scenario('caregiver_accepted', 'Đã nhận ca', caregiverId: null),
    _Scenario('pending_payment', 'Chờ thanh toán'),
    _Scenario('draft', 'Bản nháp'),
    _Scenario('in_progress', 'Đã nhận ca'),
    _Scenario('in_progress', 'Đang diễn ra', checkedIn: true),
    _Scenario('disputed', 'Đang xử lý', tab: 'Đã hủy'),
    _Scenario('refunded', 'Đã hoàn tiền', tab: 'Đã hủy'),
    _Scenario('completed', 'Hoàn thành', tab: 'Hoàn tất'),
  ];

  for (final scenario in scenarios) {
    testWidgets(
        '${scenario.status} with caregiver ${scenario.caregiverId}: '
        'card and detail show the same status', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/bookings',
        routes: [
          GoRoute(
            path: '/bookings',
            builder: (_, __) => const BookingListScreen(),
          ),
          GoRoute(
            path: '/bookings/:id',
            builder: (_, state) =>
                BookingDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_SignedOutAuth.new),
          bookingStoreProvider.overrideWith(() => _Bookings(scenario)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(scenario.tab));
      await tester.pumpAndSettle();

      final cardLabel = find.descendant(
        of: find.byType(BookingListScreen),
        matching: find.text(scenario.label),
      );
      expect(cardLabel, findsOneWidget);
      final cardColor = tester.widget<Text>(cardLabel).style!.color;
      final cardBackground = _backgroundOf(tester.element(cardLabel));
      expect(cardBackground, isNotNull);

      await tester.tap(cardLabel);
      await tester.pump();
      // Màn chờ ghép có thanh tiến trình liên tục, không chờ pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));

      final detailLabel = find.descendant(
        of: find.byKey(const Key('booking-detail-hero')),
        matching: find.text(scenario.label),
      );
      expect(detailLabel, findsOneWidget);
      expect(tester.widget<Text>(detailLabel).style!.color, cardColor);
      expect(_backgroundOf(tester.element(detailLabel)), cardBackground);
      expect(
        find.text('Đang tìm chăm sóc viên phù hợp'),
        scenario.expectWaiting ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Hệ thống đang điều phối người chăm sóc tốt nhất cho bạn.'),
        findsNothing,
      );
      if (scenario.status == 'confirmed' && !scenario.expectWaiting) {
        expect(
          find.text('Ca đã được nhận. Vui lòng chờ caregiver bắt đầu di chuyển '
              'hoặc check-in từ ứng dụng caregiver.'),
          findsNothing,
        );
        expect(
          find.text('Lịch hẹn đã được xác nhận. Bạn sẽ nhận thông báo khi '
              'chăm sóc viên cập nhật tiến trình ca.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);

      if (scenario.checkedIn) {
        final extend = find.text('Gia hạn ca chăm sóc');
        await tester.ensureVisible(extend);
        await tester.tap(extend);
        await tester.pumpAndSettle();
        expect(find.text('Chưa thể gia hạn trên ứng dụng'), findsOneWidget);
        expect(find.textContaining('đã được gửi đến caregiver'), findsNothing);
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Color? _backgroundOf(Element element) {
  Color? background;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Container && widget.decoration is BoxDecoration) {
      background = (widget.decoration! as BoxDecoration).color;
      return false;
    }
    return true;
  });
  return background;
}

class _Scenario {
  final String status;
  final String label;
  final String? caregiverId;
  final String tab;
  final bool expectWaiting;
  final bool checkedIn;

  const _Scenario(
    this.status,
    this.label, {
    this.caregiverId = 'caregiver-1',
    this.tab = 'Sắp tới',
    this.expectWaiting = false,
    this.checkedIn = false,
  });
}

class _SignedOutAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
}

class _Bookings extends BookingStore {
  final _Scenario scenario;

  _Bookings(this.scenario);

  @override
  List<BookingModel> build() => [
        BookingModel(
          id: 'booking-1',
          beneficiaryId: 'beneficiary-1',
          caregiverId: scenario.caregiverId,
          addressId: 'address-1',
          serviceTypeId: 'service-1',
          scheduledStart: DateTime(2030, 11, 1, 8),
          scheduledEnd: DateTime(2030, 11, 1, 12),
          actualStart: scenario.checkedIn
              ? DateTime.now().subtract(const Duration(minutes: 10))
              : null,
          status: scenario.status,
          escrowAmount: 300000,
          platformFeeAmount: 0,
          createdAt: DateTime(2026, 10, 8),
          updatedAt: DateTime(2026, 10, 8),
          beneficiaryName: 'Người thân',
          addressText: 'Địa chỉ mẫu',
          serviceName: 'Gói hỗ trợ sinh hoạt',
        ),
      ];
}
