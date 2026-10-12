Map<String, dynamic> nutritionJsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
List<Map<String, dynamic>> nutritionJsonObjects(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];
List<String> nutritionJsonStrings(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];
