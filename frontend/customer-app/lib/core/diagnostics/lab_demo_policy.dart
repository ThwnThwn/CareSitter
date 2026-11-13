import 'package:flutter/foundation.dart';

class LabDemoPolicy {
  static const configured = bool.fromEnvironment('LAB3_DEMO_ENABLED');
  static bool permits({required bool web, required bool enabled}) =>
      !web && enabled;
  static bool get enabled =>
      permits(web: kIsWeb, enabled: configured);
}
