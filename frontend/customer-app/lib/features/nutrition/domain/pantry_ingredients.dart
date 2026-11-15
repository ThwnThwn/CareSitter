class PantryIngredients {
  static List<String> parse(String value) => value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  static String? error(String value) {
    final items = parse(value);
    if (items.length > 20) return 'Nhập tối đa 20 nguyên liệu.';
    if (items.any((item) => item.length < 2 || item.length > 80)) {
      return 'Mỗi nguyên liệu cần từ 2 đến 80 ký tự.';
    }
    return null;
  }
}
