import 'dart:convert';

String nutritionHealthLabels(Object? raw) => raw is List
    ? raw
        .map((item) => item is Map
            ? item['label'] ?? item['code'] ?? jsonEncode(item)
            : item)
        .join('; ')
    : '';
