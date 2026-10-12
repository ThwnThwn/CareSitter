class BookingStepRules {
  const BookingStepRules._();
  static bool canContinue(
          {required int step,
          required bool service,
          required bool recipient,
          required bool schedule,
          required bool address,
          required bool caregiver,
          required bool consent}) =>
      switch (step) {
        0 => service,
        1 => recipient,
        2 => schedule && address,
        3 => caregiver,
        4 => consent,
        _ =>
          service && recipient && schedule && address && caregiver && consent,
      };
}
