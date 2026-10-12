import 'package:flutter/material.dart';

class SettingsItem {
  const SettingsItem(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}
