import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const legacyLengthExceptions = <String>{
  'lib/app/router/app_router.dart',
  'lib/features/auth/presentation/screens/password_recovery_screen.dart',
  'lib/features/auth/presentation/screens/phone_input_screen.dart',
  'lib/features/auth/presentation/screens/recovery_email_screen.dart',
  'lib/features/home/presentation/screens/home_screen.dart',
  'lib/features/schedule/presentation/screens/schedule_screen.dart',
  'lib/features/shifts/presentation/controllers/shift_list_controller.dart',
  'lib/features/shifts/presentation/screens/shift_detail_screen.dart',
};

const legacyBuildMethodExceptions = <String>{
  'lib/features/auth/presentation/screens/otp_verify_screen.dart',
  'lib/features/earnings/presentation/screens/earnings_screen.dart',
  'lib/features/home/presentation/screens/home_screen.dart',
  'lib/features/schedule/presentation/screens/schedule_screen.dart',
  'lib/features/settings/presentation/screens/document_status_screen.dart',
  'lib/features/settings/presentation/screens/settings_screen.dart',
  'lib/features/settings/presentation/screens/support_screen.dart',
  'lib/features/shifts/presentation/screens/shift_detail_screen.dart',
  'lib/features/shifts/presentation/screens/shift_list_screen.dart',
  'lib/features/shifts/presentation/screens/shift_summary_screen.dart',
};

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

Iterable<File> _allDartFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !_isGenerated(f.path));
}

void main() {
  test('core, data and presentation respect their dependency boundaries', () {
    final violations = <String>[];
    for (final file in _allDartFiles()) {
      final path = file.path.replaceAll('\\', '/');
      final source = file.readAsStringSync();
      final imports = RegExp("(?:import|export)\\s+['\"]([^'\"]+)['\"]")
          .allMatches(source)
          .map((m) => m[1]!)
          .toList();
      if (path.startsWith('lib/core/') &&
          imports.any((p) => p.contains('features/'))) {
        violations.add('$path: core → feature');
      }
      if (path.contains('/data/') &&
          imports.any((p) => p.contains('/presentation/'))) {
        violations.add('$path: data → presentation');
      }
      if (path.contains('/presentation/controllers/') &&
          imports
              .any((p) => p.contains('/screens/') || p.contains('/widgets/'))) {
        violations.add('$path: controller → UI');
      }
      if (path.contains('/presentation/') &&
          imports.any((p) => p == 'package:dio/dio.dart')) {
        violations.add('$path: presentation → Dio');
      }
      if ((path.contains('/screens/') || path.contains('/widgets/')) &&
          RegExp(r'(?:read|watch)\(\s*\w+RepositoryProvider')
              .hasMatch(source)) {
        violations.add('$path: UI → repository');
      }
      if (path.contains('/domain/') &&
          imports.any((p) =>
              p.startsWith('package:flutter/') ||
              p.contains('riverpod') ||
              p.contains('dio/'))) {
        violations.add('$path: domain → framework');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
      'all non-generated dart files stay below 300 lines with shrinking exceptions',
      () {
    final violations = <String>[];
    final staleExceptions = <String>[];

    for (final file in _allDartFiles()) {
      final path = file.path.replaceAll('\\', '/');
      final lineCount = file.readAsLinesSync().length;
      final isExcepted = legacyLengthExceptions.contains(path);

      if (lineCount > 300) {
        if (!isExcepted) {
          violations.add('$path exceeds 300 lines ($lineCount lines)');
        }
      } else if (isExcepted) {
        staleExceptions.add(
            '$path is down to $lineCount lines (<= 300). Remove it from legacyLengthExceptions.');
      }
    }

    expect(staleExceptions, isEmpty,
        reason:
            'Stale exceptions that must be removed:\n${staleExceptions.join('\n')}');
    expect(violations, isEmpty,
        reason:
            'New files or unexcepted files exceeding 300 lines:\n${violations.join('\n')}');
  });

  test(
      'UI files do not define Widget _build methods with shrinking exceptions',
      () {
    final pattern = RegExp(r'Widget\s+_build\w*\s*\(');
    final violations = <String>[];
    final staleExceptions = <String>[];

    for (final file in _allDartFiles()) {
      final path = file.path.replaceAll('\\', '/');
      final content = file.readAsStringSync();
      final hasBuild = pattern.hasMatch(content);
      final isExcepted = legacyBuildMethodExceptions.contains(path);

      if (hasBuild) {
        if (!isExcepted) {
          violations.add('$path defines Widget _build... helper methods');
        }
      } else if (isExcepted) {
        staleExceptions.add(
            '$path no longer contains _build methods. Remove it from legacyBuildMethodExceptions.');
      }
    }

    expect(staleExceptions, isEmpty,
        reason:
            'Stale exceptions that must be removed:\n${staleExceptions.join('\n')}');
    expect(violations, isEmpty,
        reason:
            'New files or unexcepted files containing Widget _build methods:\n${violations.join('\n')}');
  });
}
