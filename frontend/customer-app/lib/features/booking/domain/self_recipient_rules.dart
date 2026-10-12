class SelfRecipientRules {
  const SelfRecipientRules._();
  static bool isComplete(
          String name, List<({String name, String phone})> contacts) =>
      name.trim().isNotEmpty &&
      contacts.length >= 2 &&
      contacts.map((c) => c.phone).toSet().length == contacts.length &&
      contacts.every((c) =>
          c.name.trim().isNotEmpty &&
          RegExp(r'^0[3-9][0-9]{8}$').hasMatch(c.phone));
}
