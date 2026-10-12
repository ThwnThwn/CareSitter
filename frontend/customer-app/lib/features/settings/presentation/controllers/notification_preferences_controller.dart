import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';
import 'package:caresitter_customer/features/settings/data/repositories/settings_repository.dart';
import 'notification_preferences_state.dart';

export 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';

final notificationPrefsProvider = StateNotifierProvider.autoDispose<
    NotificationPrefsNotifier, AsyncValue<NotificationPreferencesState>>((ref) {
  return NotificationPrefsNotifier(
      ref.read(settingsRepositoryProvider), AuthSessionScope.watch(ref));
});

class NotificationPrefsNotifier
    extends StateNotifier<AsyncValue<NotificationPreferencesState>> {
  final SettingsRepository _repository;
  final AuthSessionScope _session;
  Timer? _debounce;
  NotificationPrefs? _queued;
  bool _saving = false;
  int _revision = 0;
  bool get _active => mounted && _session.isCurrent;

  NotificationPrefsNotifier(this._repository, this._session)
      : super(const AsyncLoading()) {
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _session.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_active) return;
    try {
      final prefs = await _repository.getNotificationPreferences(
          cancellation: _session.cancellation);
      if (_active) state = AsyncData(NotificationPreferencesState(prefs));
    } catch (error, stack) {
      if (_active) state = AsyncError(error, stack);
    }
  }

  void toggle(NotificationPrefs updated) {
    if (!_active || !state.hasValue) return;
    _revision++;
    _queued = updated;
    state = AsyncData(NotificationPreferencesState(updated, saving: true));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _drain);
  }

  void retrySave() {
    final draft = state.valueOrNull;
    if (draft != null) toggle(draft.preferences);
  }

  // Serialize writes so a slow earlier request cannot win over the last edit.
  Future<void> _drain() async {
    if (!_active || _saving || _queued == null) return;
    _saving = true;
    final preferences = _queued!;
    _queued = null;
    final revision = _revision;
    try {
      await _repository.saveNotificationPreferences(preferences,
          cancellation: _session.cancellation);
      if (_active && revision == _revision) {
        state = AsyncData(NotificationPreferencesState(preferences));
      }
    } catch (_) {
      if (_active && revision == _revision) {
        state =
            AsyncData(NotificationPreferencesState(preferences, saveError: true));
      }
    } finally {
      _saving = false;
      if (_active && _queued != null && _debounce?.isActive != true) {
        unawaited(_drain());
      }
    }
  }
}
