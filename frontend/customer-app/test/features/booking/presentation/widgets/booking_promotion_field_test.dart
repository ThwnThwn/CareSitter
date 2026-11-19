import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_promotion_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_selectors.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_state.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/booking_wizard_footer.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/wizard/common/booking_promotion_field.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:caresitter_customer/features/promotions/data/repositories/promotion_repository.dart';
import 'package:caresitter_customer/features/promotions/presentation/controllers/active_promotions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/promotion_test_repository.dart';
import '../../../../support/session_test_auth.dart';

const _args = (serviceId: 'service', beneficiaryId: null, caregiverId: null);

void main() {
  testWidgets('choose, enter and remove vouchers with server-quoted totals',
      (tester) async {
    final repository = PromotionTestRepository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(SessionTestAuth.new),
      promotionRepositoryProvider.overrideWithValue(repository),
      activePromotionsProvider.overrideWith((ref) async => [
            PromotionModel(
              id: 'care20',
              code: 'CARE20',
              title: 'Ưu đãi đặt lịch',
              summary: 'Giảm cho lịch chăm sóc',
              badgeText: 'Giảm 20%',
              minOrderAmount: 100000,
              endsAt: DateTime(2027),
              eligibleServiceIds: ['service'],
            ),
            PromotionModel(
              id: 'another',
              code: 'OTHER',
              title: 'Dịch vụ khác',
              summary: '',
              badgeText: 'Giảm 10%',
              endsAt: DateTime(2027),
              eligibleServiceIds: ['other-service'],
            ),
          ]),
      bookingWizardProvider.overrideWith(_Wizard.new),
      wizardCanContinueProvider.overrideWith((ref, args) => true),
    ]);
    addTearDown(container.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: BookingPromotionField(
                      args: _args, estimatedAmount: 180000),
                ),
              ),
              BookingWizardFooter(args: _args, onSubmit: () {}),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    ElevatedButton confirm() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(confirm().onPressed, isNotNull);
    expect(find.text('180.000đ'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Mã ưu đãi'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mã ưu đãi'), findsOneWidget);
    expect(find.text('Dịch vụ khác'), findsNothing);
    await tester.tap(find.text('Ưu đãi đặt lịch'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'CARE20');
    await tester.tap(find.text('Áp dụng'));
    await tester.pump();
    expect(find.text('Đang kiểm tra…'), findsOneWidget);
    expect(container.read(bookingPromotionProvider(_args)).checking, isTrue);
    repository.requests.single.response.complete(care20Quote);
    await tester.pumpAndSettle();
    expect(find.text('150.000đ'), findsOneWidget);
    expect(find.text('-30.000đ'), findsOneWidget);
    expect(find.text('120.000đ'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('CARE20 · Giảm'), findsOneWidget);
    expect(confirm().onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mã ưu đãi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' expired ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pump();
    expect(repository.requests.last.code, 'EXPIRED');
    repository.requests.last.response
        .completeError(const AppApiException(message: 'Mã ưu đãi đã hết hạn.'));
    await tester.pumpAndSettle();
    expect(find.text('Mã ưu đãi đã hết hạn.'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng ưu đãi'));
    await tester.pumpAndSettle();
    expect(find.text('120.000đ'), findsOneWidget);

    container.read(bookingWizardProvider(_args).notifier).setDuration(3);
    await tester.pumpAndSettle();
    expect(find.textContaining('áp dụng lại mã'), findsOneWidget);
    expect(find.text('120.000đ'), findsNothing);
    expect(confirm().onPressed, isNull);
    await tester.tap(find.text('Mã ưu đãi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ mã'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn hoặc nhập mã'), findsOneWidget);
    expect(confirm().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

class _Wizard extends BookingWizardController {
  @override
  BookingWizardState build(BookingWizardArgs arg) => BookingWizardState(
        step: 5,
        serviceId: arg.serviceId,
        date: DateTime(2027, 1, 1),
        startMinutes: 480,
      );
}
