import '../../data/models/notification_preferences.dart';

class NotificationPreferencesState {
  const NotificationPreferencesState(this.preferences,
      {this.saving = false, this.saveError = false});

  final NotificationPrefs preferences;
  final bool saving;
  final bool saveError;
}
