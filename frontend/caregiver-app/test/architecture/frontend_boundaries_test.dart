import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() {
  test('core, data and presentation respect their dependency boundaries', () {
    final violations = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
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
      if (path.contains('/data/models/') &&
          imports.any((p) =>
              p.startsWith('package:flutter/') || p.contains('riverpod'))) {
        violations.add('$path: model → framework');
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
      final feature = RegExp(r'^lib/features/([^/]+)/').firstMatch(path)?[1];
      if (feature != null) {
        for (final uri in imports) {
          final imported = uri.startsWith('package:caregiver_app/')
              ? uri.replaceFirst('package:caregiver_app/', 'lib/')
              : !uri.contains(':')
                  ? file.uri.resolve(uri).toFilePath().replaceAll('\\', '/')
                  : uri;
          final target = RegExp(
                  r'(?:^|/)features/([^/]+)/presentation/(screens|widgets|models)/')
              .firstMatch(imported);
          if (target != null && target[1] != feature) {
            violations.add('$path: UI nội bộ của feature khác ($uri)');
          }
        }
      }
      if (path.contains('/presentation/controllers/') &&
          RegExp(r'\b(BuildContext|Navigator|SnackBar|showDialog)\b')
              .hasMatch(source)) {
        violations.add('$path: controller → UI operation');
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
  test('all caregiver widgets stay within the file and build size limits', () {
    final violations = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      final parsed = parseString(content: source);
      final classes = parsed.unit.declarations
          .whereType<ClassDeclaration>()
          .where((c) => RegExp(
                  r'^(?:Consumer)?(?:StatelessWidget|StatefulWidget|Widget|State)(?:<|$)')
              .hasMatch(c.extendsClause?.superclass.toSource() ?? ''))
          .toList();
      if (classes.isEmpty) continue;
      if (file.readAsLinesSync().length > 300) {
        violations.add('${file.path}: file > 300 lines');
      }
      for (final c in classes) {
        for (final method in c.members.whereType<MethodDeclaration>().where(
            (m) =>
                m.name.lexeme == 'build' ||
                m.name.lexeme.startsWith('_build'))) {
          final start = parsed.lineInfo.getLocation(method.offset).lineNumber;
          final end = parsed.lineInfo.getLocation(method.end).lineNumber;
          if (end - start + 1 > 80) {
            violations.add('${file.path}: ${method.name.lexeme} > 80 lines');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
