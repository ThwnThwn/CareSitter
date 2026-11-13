import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../widgets/crash_demo_panel.dart';
import '../widgets/runtime_config_panel.dart';
import '../widgets/push_permission_panel.dart';

class LabDiagnosticsScreen extends StatelessWidget {
  const LabDiagnosticsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Kiểm chứng Lab3')),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
            CrashDemoPanel(),
            SizedBox(height: AppSpacing.lg),
            RuntimeConfigPanel(),
            PushPermissionPanel(),
          ])));
}
