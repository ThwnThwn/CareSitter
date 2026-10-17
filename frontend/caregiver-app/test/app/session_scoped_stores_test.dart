import 'dart:async';
import 'dart:io';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/profile/data/repositories/profile_repository.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';
import 'package:caregiver_app/features/earnings/presentation/controllers/earnings_controller.dart';

AuthState session(String id) => AuthState(
    userId: id,
    accessToken: 'test',
    refreshToken: 'test',
    phone: '',
    roles: const ['CAREGIVER'],
    isAuthenticated: true);

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => session('first');
  void switchTo(String id) => state = AsyncData(session(id));
}

class _Profiles implements ProfileRepository {
  final profiles = <Completer<CaregiverProfileModel>>[];
  final avatars = <Completer<bool>>[];
  final kyc = Completer<void>();
  ApiCancellation? kycCancellation;
  @override
  Future<void> submitKyc(
      {required String cccdNumber,
      required File cccdFront,
      required File cccdBack,
      List<File> certificates = const [],
      ApiCancellation? cancellation}) {
    kycCancellation = cancellation;
    return kyc.future;
  }

  @override
  Future<CaregiverProfileModel> getOrCreateProfile({String? fallbackName}) {
    final pending = Completer<CaregiverProfileModel>();
    profiles.add(pending);
    return pending.future;
  }

  @override
  Future<bool> uploadAvatar(File file) {
    final pending = Completer<bool>();
    avatars.add(pending);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Shifts extends ShiftRepository {
  _Shifts() : super(_UnusedShiftClient());
  final loads = <Completer<List<Map<String, dynamic>>>>[];
  final accepted = Completer<Map<String, dynamic>>();
  int accepts = 0;
  @override
  Future<Map<String, dynamic>> acceptBooking(String id) {
    accepts++;
    return accepted.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getShifts(
      {String? status, int page = 1, int pageSize = 50}) {
    final pending = Completer<List<Map<String, dynamic>>>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getOpenOffers(
          {int page = 1, int pageSize = 20}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedShiftClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Realtime implements CareSignalRService {
  int taskListeners = 0;
  late final tasks = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () => taskListeners++, onCancel: () => taskListeners--);
  final statuses = StreamController<BookingStatusChange>.broadcast();
  final offers = StreamController<BookingOfferChange>.broadcast();
  final reconnects = StreamController<void>.broadcast();
  @override
  Future<void> connect() async {}
  @override
  Stream<Map<String, dynamic>> get onTaskUpdated => tasks.stream;
  @override
  Stream<BookingStatusChange> get statusStream => statuses.stream;
  @override
  Stream<BookingOfferChange> get offerStream => offers.stream;
  @override
  Stream<void> get onReconnected => reconnects.stream;
  Future<void> close() async {
    await tasks.close();
    await statuses.close();
    await offers.close();
    await reconnects.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Wallet implements EarningsRepository {
  final loads = <Completer<double>>[];
  final withdrawal = Completer<void>();
  int withdrawals = 0;
  final keys = <String?>[];
  @override
  Future<double> getAvailableBalance() {
    final pending = Completer<double>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<void> requestWithdrawal(
      {required double amount,
      required String bankName,
      required String bankBin,
      required String accountHolderName,
      required String accountNumber,
      required String idempotencyKey}) {
    withdrawals++;
    keys.add(idempotencyKey);
    return withdrawal.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('old profile response cannot populate another account', () async {
    final profiles = _Profiles();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      profileRepositoryProvider.overrideWithValue(profiles),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    container.read(profileProvider);
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    container.read(profileProvider);
    profiles.profiles.last
        .complete(const CaregiverProfileModel(id: 'new', userId: 'second'));
    await flush();
    profiles.profiles.first
        .complete(const CaregiverProfileModel(id: 'old', userId: 'first'));
    await flush();
    expect(container.read(profileProvider).userId, 'second');
  });

  test('old avatar completion does not release the new account upload lock',
      () async {
    final profiles = _Profiles();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      profileRepositoryProvider.overrideWithValue(profiles)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final oldUpload = container
        .read(profileProvider.notifier)
        .uploadAvatar(File('test-image'));
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    final newUpload = container
        .read(profileProvider.notifier)
        .uploadAvatar(File('test-image'));
    profiles.avatars.first.complete(true);
    expect(await oldUpload, isFalse);
    expect(container.read(caregiverAvatarUploadingProvider), isTrue);
    profiles.avatars.last.complete(false);
    expect(await newUpload, isFalse);
    expect(container.read(caregiverAvatarUploadingProvider), isFalse);
  });

  test(
      'latest shift refresh wins and owned realtime subscriptions are canceled',
      () async {
    final shifts = _Shifts();
    final realtime = _Realtime();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      shiftRepositoryProvider.overrideWithValue(shifts),
      careSignalRProvider.overrideWithValue(realtime)
    ]);
    await container.read(authStateProvider.future);
    final controller = container.read(shiftsProvider.notifier);
    await flush();
    final latest = controller.refresh();
    shifts.loads.last.complete([
      {'id': 'new', 'status': 'in_progress'}
    ]);
    await latest;
    shifts.loads.first.complete([
      {'id': 'old', 'status': 'in_progress'}
    ]);
    await flush();
    expect(container.read(shiftsProvider).single.id, 'new');
    expect(realtime.taskListeners, 1);
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    expect(container.read(shiftsProvider), isEmpty);
    await flush();
    expect(realtime.taskListeners, 1);
    container.dispose();
    await flush();
    expect(realtime.taskListeners, 0);
    await realtime.close();
  });

  test('old wallet response is ignored and withdrawal double tap is locked',
      () async {
    final wallet = _Wallet();
    final shifts = _Shifts();
    final realtime = _Realtime();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      earningsRepositoryProvider.overrideWithValue(wallet),
      shiftRepositoryProvider.overrideWithValue(shifts),
      careSignalRProvider.overrideWithValue(realtime)
    ]);
    await container.read(authStateProvider.future);
    container.read(earningsProvider);
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    final controller = container.read(earningsProvider.notifier);
    wallet.loads.last.complete(1000000);
    await flush();
    wallet.loads.first.complete(50);
    await flush();
    expect(container.read(earningsProvider).balance, 1000000);
    final first = controller.withdraw(100000,
        bankName: 'Bank',
        bankBin: '970436',
        accountNumber: '1234',
        accountHolderName: 'Name');
    expect(
        await controller.withdraw(100000,
            bankName: 'Bank',
            bankBin: '970436',
            accountNumber: '1234',
            accountHolderName: 'Name'),
        WithdrawalResult.ignored);
    expect(wallet.withdrawals, 1);
    wallet.withdrawal.completeError(StateError('transport failure'));
    expect(await first, WithdrawalResult.unknown);
    expect(
        await controller.withdraw(200000,
            bankName: 'Bank',
            bankBin: '970436',
            accountNumber: '1234',
            accountHolderName: 'Name'),
        WithdrawalResult.changedPayload);
    expect(wallet.withdrawals, 1,
        reason: 'An unknown payout cannot be replaced with another payload.');
    expect(
        await controller.withdraw(100000,
            bankName: 'Bank',
            bankBin: '970436',
            accountNumber: '1234',
            accountHolderName: 'Name'),
        WithdrawalResult.unknown);
    expect(wallet.withdrawals, 2);
    expect(wallet.keys.first, isNotNull);
    expect(wallet.keys.last, wallet.keys.first);
    container.dispose();
    await realtime.close();
  });

  test('switching account cancels an in-flight KYC pipeline', () async {
    final profiles = _Profiles();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      profileRepositoryProvider.overrideWithValue(profiles)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final old = container.read(profileProvider.notifier);
    final submission = old.submitKyc(
        cccdNumber: 'test', cccdFront: File('front'), cccdBack: File('back'));
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    container.read(profileProvider);
    expect(profiles.kycCancellation!.isCancelled, isTrue);
    profiles.kyc.complete();
    await submission;
    expect(profiles.profiles.length, 2,
        reason: 'The old submission must not refresh a new account.');
  });

  test(
      'lifecycle lock blocks another mutation on the same shift until refresh completes',
      () async {
    final shifts = _Shifts();
    final realtime = _Realtime();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      shiftRepositoryProvider.overrideWithValue(shifts),
      careSignalRProvider.overrideWithValue(realtime)
    ]);
    await container.read(authStateProvider.future);
    final controller = container.read(shiftsProvider.notifier);
    shifts.loads.first.complete([]);
    await flush();
    final first = controller.acceptBooking('offer');
    await expectLater(controller.acceptBooking('offer'), throwsException);
    expect(shifts.accepts, 1);
    shifts.accepted.complete({});
    await flush();
    shifts.loads.last.complete([]);
    await first;
    container.dispose();
    await realtime.close();
  });
}
