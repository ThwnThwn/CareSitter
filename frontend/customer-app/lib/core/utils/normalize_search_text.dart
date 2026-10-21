String normalizeSearchText(String value) {
  var normalized = value.trim().toLowerCase();
  const groups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in groups.entries) {
    for (final codePoint in entry.value.runes) {
      normalized = normalized.replaceAll(
        String.fromCharCode(codePoint),
        entry.key,
      );
    }
  }
  return normalized.replaceAll(RegExp(r'\s+'), ' ');
}
