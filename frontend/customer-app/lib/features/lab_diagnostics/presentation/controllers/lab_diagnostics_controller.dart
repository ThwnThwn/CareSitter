import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';
import 'package:caresitter_customer/core/diagnostics/lab_demo_policy.dart';

final labDiagnosticsControllerProvider =
    AutoDisposeNotifierProvider<LabDiagnosticsController, AsyncValue<String?>>(
        LabDiagnosticsController.new);

class LabDiagnosticsController
    extends AutoDisposeNotifier<AsyncValue<String?>> {
  bool _active = true;
  @override
  AsyncValue<String?> build() {
    _active = true;
    ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
    ref.onDispose(() => _active = false);
    return const AsyncData(null);
  }

  Future<void> trigger({required bool fatal}) async {
    if (state.isLoading) return;
    final reporter = ref.read(crashReporterProvider);
    if (!LabDemoPolicy.enabled ||
        !reporter.available ||
        ref.read(authStateProvider).valueOrNull?.isAuthenticated != true) {
      state = AsyncError(
          StateError('Chỉ dùng trên bản demo native đã cấu hình Crashlytics.'),
          StackTrace.current);
      return;
    }
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    final run = const Uuid().v4();
    state = const AsyncLoading();
    try {
      if (fatal) {
        await reporter.crashDemo(run);
      } else {
        await reporter.nonfatalDemo(run);
      }
      if (_active &&
          generation ==
              ref.read(authStateProvider.notifier).sessionGeneration) {
        state = AsyncData(run);
      }
    } catch (error, stack) {
      if (_active &&
          generation ==
              ref.read(authStateProvider.notifier).sessionGeneration) {
        state = AsyncError(error, stack);
      }
    }
  }
}
