import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';
import 'package:caresitter_customer/features/settings/data/repositories/settings_repository.dart';

export 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';

final notificationPrefsProvider = StateNotifierProvider<
    NotificationPrefsNotifier,
    AsyncValue<NotificationPrefs>>((ref) => NotificationPrefsNotifier(ref));

class NotificationPrefsNotifier
    extends StateNotifier<AsyncValue<NotificationPrefs>> {
  final Ref _ref;
  Timer? _debounce;

  NotificationPrefsNotifier(this._ref) : super(const AsyncLoading()) {
    _load();
  }

  SettingsRepository get _repository => _ref.read(settingsRepositoryProvider);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      state = AsyncData(await _repository.getNotificationPreferences());
    } catch (_) {
      state = const AsyncData(NotificationPrefs());
    }
  }

  void toggle(NotificationPrefs updated) {
    state = AsyncData(updated);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _save(updated));
  }

  Future<void> _save(NotificationPrefs preferences) async {
    try {
      await _repository.saveNotificationPreferences(preferences);
    } catch (_) {
      // Auto-save không rollback để giữ trải nghiệm cũ.
    }
  }
}
