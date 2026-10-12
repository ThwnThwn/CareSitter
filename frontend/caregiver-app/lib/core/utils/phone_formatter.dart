String normalizePhone(String value) {
  final phone = value.replaceAll(RegExp(r'[\s().-]'), '');
  return phone.startsWith('+84') ? '0${phone.substring(3)}' : phone;
}
