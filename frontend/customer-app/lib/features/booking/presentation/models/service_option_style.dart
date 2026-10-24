import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter/material.dart';

class ServiceOptionStyle {
  const ServiceOptionStyle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;

  factory ServiceOptionStyle.fromService(ServiceModel service) {
    final name = _splitName(service.name);
    final code = service.code.toUpperCase();

    if (code.contains('NONMED_ESSENTIAL')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.home_rounded,
        iconBackground: AppColors.limeLight,
        iconForeground: AppColors.limeDark,
      );
    }
    if (code.contains('NONMED_COMPANION')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.directions_walk_rounded,
        iconBackground: AppColors.softBlue,
        iconForeground: AppColors.brightBlue,
      );
    }
    if (code.contains('NONMED_DAY')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.wb_sunny_rounded,
        iconBackground: AppColors.amberSurface,
        iconForeground: AppColors.brownOrange,
      );
    }
    if (code.contains('NONMED_NIGHT')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.dark_mode_rounded,
        iconBackground: AppColors.softBlue,
        iconForeground: AppColors.brightBlue,
      );
    }

    if (code.contains('DONGHANH')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.directions_walk_rounded,
        iconBackground: AppColors.softBlue,
        iconForeground: AppColors.brightBlue,
      );
    }
    if (code.contains('PHUCHOI')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.accessibility_new_rounded,
        iconBackground: AppColors.softGreen,
        iconForeground: AppColors.primary,
      );
    }
    if (code.contains('DUONG')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.restaurant_rounded,
        iconBackground: AppColors.limeLight,
        iconForeground: AppColors.limeDark,
      );
    }
    if (code.contains('DEM')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.dark_mode_rounded,
        iconBackground: AppColors.amberSurface,
        iconForeground: AppColors.brownOrange,
      );
    }
    if (code.contains('TAM')) {
      return ServiceOptionStyle(
        title: name.$1,
        subtitle: name.$2,
        icon: Icons.volunteer_activism_rounded,
        iconBackground: AppColors.pinkLight,
        iconForeground: AppColors.pinkDark,
      );
    }
    return ServiceOptionStyle(
      title: name.$1,
      subtitle: name.$2,
      icon: Icons.auto_awesome_rounded,
      iconBackground: AppColors.primaryContainer,
      iconForeground: AppColors.primary,
    );
  }

  static (String, String?) _splitName(String value) {
    final match = RegExp(r'^(.*?)\s*(\([^)]*\))\s*$').firstMatch(value.trim());
    if (match == null) return (value.trim(), null);
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }
}
