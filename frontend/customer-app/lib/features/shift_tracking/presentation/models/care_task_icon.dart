import 'package:flutter/material.dart';

IconData iconForCareTask(String title) {
  final t = title.toLowerCase();
  if (t.contains('check-in') || t.contains('check in')) {
    return Icons.login_rounded;
  }
  if (t.contains('ăn') || t.contains('bữa')) {
    return Icons.restaurant_menu_outlined;
  }
  if (t.contains('tắm') || t.contains('vệ sinh')) {
    return Icons.shower_outlined;
  }
  if (t.contains('tập') || t.contains('lý liệu') || t.contains('vận động')) {
    return Icons.directions_walk_outlined;
  }
  if (t.contains('ngủ') || t.contains('nghỉ')) {
    return Icons.bed_outlined;
  }
  if (t.contains('báo cáo') || t.contains('kết thúc')) {
    return Icons.assignment_turned_in_outlined;
  }
  if (t.contains('uống') || t.contains('dùng')) {
    return Icons.local_cafe_outlined;
  }
  return Icons.task_alt_outlined;
}
