class NotificationPrefs {
  final bool bookingUpdates;
  final bool paymentUpdates;
  final bool caregiverArriving;
  final bool scheduleReminder;
  final bool chatMessage;
  final bool promotion;

  const NotificationPrefs({
    this.bookingUpdates = true,
    this.paymentUpdates = true,
    this.caregiverArriving = true,
    this.scheduleReminder = true,
    this.chatMessage = true,
    this.promotion = false,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      bookingUpdates:
          (json['bookingUpdates'] ?? json['BookingUpdates'] ?? true) == true,
      paymentUpdates:
          (json['paymentUpdates'] ?? json['PaymentUpdates'] ?? true) == true,
      caregiverArriving:
          (json['caregiverArriving'] ?? json['CaregiverArriving'] ?? true) ==
              true,
      scheduleReminder:
          (json['scheduleReminder'] ?? json['ScheduleReminder'] ?? true) ==
              true,
      chatMessage: (json['chatMessage'] ?? json['ChatMessage'] ?? true) == true,
      promotion: (json['promotion'] ?? json['Promotion'] ?? false) == true,
    );
  }

  NotificationPrefs copyWith({
    bool? bookingUpdates,
    bool? paymentUpdates,
    bool? caregiverArriving,
    bool? scheduleReminder,
    bool? chatMessage,
    bool? promotion,
  }) {
    return NotificationPrefs(
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      paymentUpdates: paymentUpdates ?? this.paymentUpdates,
      caregiverArriving: caregiverArriving ?? this.caregiverArriving,
      scheduleReminder: scheduleReminder ?? this.scheduleReminder,
      chatMessage: chatMessage ?? this.chatMessage,
      promotion: promotion ?? this.promotion,
    );
  }
}
