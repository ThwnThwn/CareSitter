import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_promotion_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_wizard_state.dart';
import 'package:caresitter_customer/features/promotions/data/repositories/promotion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/promotion_test_repository.dart';
import '../../../../support/session_test_auth.dart';

void main() {
  const args = (serviceId: 'service', beneficiaryId: null, caregiverId: null);
  final provider = bookingPromotionProvider(args);
  final slot = BookingWizardState(
          serviceId: 'service', date: DateTime(2027, 1, 1), startMinutes: 480)
      .promotionSlot!;
  late ProviderContainer container;
  late PromotionTestRepository repository;

  setUp(() async {
    repository = PromotionTestRepository();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(SessionTestAuth.new),
      promotionRepositoryProvider.overrideWithValue(repository),
    ]);
    await container.read(authStateProvider.future);
    container.listen(provider, (_, __) {});
  });
  tearDown(() => container.dispose());

  test('only a matching server quote makes an entered code ready', () async {
    final controller = container.read(provider.notifier);
    controller.setCode(' care20 ');
    final pending = controller.apply(slot);
    expect(repository.requests.single.code, 'CARE20');
    expect(container.read(provider).canSubmitFor(slot), isFalse);
    repository.requests.single.response.complete(care20Quote);
    await pending;
    expect(container.read(provider).quoteFor(slot), care20Quote);
    expect(container.read(provider).canSubmitFor(slot), isTrue);
    final newTime = (
      serviceTypeId: slot.serviceTypeId,
      start: slot.start,
      end: slot.end.add(const Duration(hours: 1)),
    );
    expect(container.read(provider).canSubmitFor(newTime), isFalse);
    controller.requireReapply('Áp dụng lại mã.');
    expect(container.read(provider).hasCode, isTrue);
    expect(container.read(provider).quote, isNull);
  });

  test('editing cancels an outdated request and rejection preserves the code',
      () async {
    final controller = container.read(provider.notifier);
    controller.setCode('CARE20');
    final ignored = controller.apply(slot);
    controller.setCode('EXPIRED');
    final outdated = repository.requests.single;
    expect(outdated.cancellation.isCancelled, isTrue);
    outdated.response.complete(care20Quote);
    await ignored;
    expect(container.read(provider).quote, isNull);
    final rejected = controller.apply(slot);
    repository.requests.last.response.completeError(const AppApiException(
        message: 'Ưu đãi đã hết hạn.',
        statusCode: 409,
        code: 'promotion.not_active'));
    await rejected;
    expect(container.read(provider).code, 'EXPIRED');
    expect(container.read(provider).error, 'Ưu đãi đã hết hạn.');
    expect(container.read(provider).canSubmitFor(slot), isFalse);
    controller.setCode('');
    expect(container.read(provider).canSubmitFor(slot), isTrue);
  });

  test('a new login for the same user clears and cancels the preview',
      () async {
    final controller = container.read(provider.notifier);
    controller.setCode('CARE20');
    final pending = controller.apply(slot);
    final request = repository.requests.single;
    (container.read(authStateProvider.notifier) as SessionTestAuth)
        .switchTo('first');
    await flushSessionWork();
    expect(request.cancellation.isCancelled, isTrue);
    request.response.complete(care20Quote);
    await pending;
    expect(container.read(provider).hasCode, isFalse);
    expect(container.read(provider).quote, isNull);
  });

  test('dismissed replacement cannot overwrite the already applied voucher',
      () async {
    final controller = container.read(provider.notifier);
    final first = controller.apply(slot, candidateCode: 'care20');
    repository.requests.single.response.complete(care20Quote);
    expect(await first, isNull);

    final replacement = controller.apply(slot, candidateCode: 'other');
    final request = repository.requests.last;
    expect(container.read(provider).canSubmitFor(slot), isFalse);
    controller.cancelPreview();
    expect(request.cancellation.isCancelled, isTrue);
    request.response.complete(care20Quote);
    await replacement;
    expect(container.read(provider).quoteFor(slot), care20Quote);
    expect(container.read(provider).canSubmitFor(slot), isTrue);
  });
}
