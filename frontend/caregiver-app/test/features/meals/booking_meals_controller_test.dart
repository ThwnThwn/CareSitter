import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meals_model.dart';
import 'package:caregiver_app/features/meals/data/models/booking_meal_record_model.dart';
import 'package:caregiver_app/features/meals/data/repositories/booking_meals_repository.dart';
import 'package:caregiver_app/features/meals/presentation/controllers/booking_meals_controller.dart';

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'first', isAuthenticated: true);
  void switchUser() => state =
      const AsyncData(AuthState(userId: 'second', isAuthenticated: true));
}

class _Repository extends BookingMealsRepository {
  _Repository() : super(_Client());
  final keys = <String>[];
  bool failOnce = false;
  Completer<BookingMealRecordModel>? pending;
  @override
  Future<BookingMealRecordModel> correct(String bookingId,
          {required String recordId,
          required String outcome,
          required String reason,
          required int expectedRevision,
          required String idempotencyKey,
          String? note,
          ApiCancellation? token}) =>
      record(bookingId,
          planId: 'plan',
          recipeVersionId: 'recipe',
          mealType: 'lunch',
          outcome: outcome,
          note: note,
          idempotencyKey: idempotencyKey);
  @override
  Future<BookingMealsModel> load(String id, {ApiCancellation? token}) async =>
      const BookingMealsModel(plans: [], records: []);
  @override
  Future<BookingMealRecordModel> record(String bookingId,
      {required String planId,
      required String recipeVersionId,
      required String mealType,
      required String outcome,
      required String idempotencyKey,
      String? note,
      ApiCancellation? token}) async {
    keys.add(idempotencyKey);
    if (failOnce) {
      failOnce = false;
      throw StateError('Lost response');
    }
    if (pending != null) return pending!.future;
    return _record();
  }
}

BookingMealRecordModel _record() => BookingMealRecordModel(
    id: 'record',
    planId: 'plan',
    plannedDate: '2026-11-14',
    recipeVersionId: 'recipe',
    mealType: 'lunch',
    outcome: 'eaten',
    recordedBy: 'first',
    recordedAt: DateTime.utc(2026, 11, 14),
    timelineEventId: 'event');

class _Client implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late ProviderContainer container;
  late _Repository repository;
  setUp(() async {
    repository = _Repository();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      bookingMealsRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    container.listen(bookingMealsProvider('booking'), (_, __) {});
    await container.read(bookingMealsProvider('booking').future);
  });
  Future<bool> write() =>
      container.read(bookingMealsProvider('booking').notifier).record(
          planId: 'plan',
          recipeVersionId: 'recipe',
          mealType: 'lunch',
          outcome: 'eaten');

  test('response-loss retry reuses the key and double taps do not send twice',
      () async {
    repository.failOnce = true;
    expect(await write(), isFalse);
    repository.pending = Completer<BookingMealRecordModel>();
    final retry = write();
    expect(await write(), isFalse);
    expect(repository.keys.length, 2);
    expect(repository.keys[0], repository.keys[1]);
    repository.pending!.complete(_record());
    expect(await retry, isTrue);
  });
  test('completion from an old account cannot update the new account',
      () async {
    repository.pending = Completer<BookingMealRecordModel>();
    final oldWrite = write();
    (container.read(authStateProvider.notifier) as _Auth).switchUser();
    await container.read(bookingMealsProvider('booking').future);
    repository.pending!.complete(_record());
    expect(await oldWrite, isFalse);
    expect(container.read(bookingMealsProvider('booking')).requireValue.records,
        isEmpty);
  });
  test('correction retry keeps its key and changed reason gets a new operation',
      () async {
    Future<bool> correct(String reason) =>
        container.read(bookingMealsProvider('booking').notifier).correct(
            recordId: 'record',
            outcome: 'eaten',
            reason: reason,
            expectedRevision: 1);
    repository.failOnce = true;
    expect(await correct('Bấm nhầm'), isFalse);
    expect(await correct('Bấm nhầm'), isTrue);
    expect(repository.keys[0], repository.keys[1]);
    expect(await correct('Đính chính khác'), isTrue);
    expect(repository.keys[2], isNot(repository.keys[1]));
  });
}
