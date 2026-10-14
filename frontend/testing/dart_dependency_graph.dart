import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Resolve imports, exports and conditional branches, not just package strings.
List<String> dependencyViolations(String packageName) {
  final root = Directory('lib').absolute.uri;
  final graph = <String, Set<String>>{};
  final violations = <String>[];
  String relative(Uri uri) => uri.toString().substring(root.toString().length);
  Uri? localTarget(Uri from, String name) {
    if (name.startsWith('package:$packageName/')) {
      return root.resolve(name.substring('package:$packageName/'.length));
    }
    if (Uri.parse(name).hasScheme) return null;
    final resolved = from.resolve(name);
    return resolved.toString().startsWith(root.toString()) ? resolved : null;
  }

  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()
      .where((file) => file.path.endsWith('.dart'))) {
    final path = relative(file.absolute.uri);
    final unit = parseString(content: file.readAsStringSync()).unit;
    final edges = graph.putIfAbsent(path, () => {});
    for (final directive in unit.directives.whereType<NamespaceDirective>()) {
      final names = [directive.uri.stringValue,
        ...directive.configurations.map((config) => config.uri.stringValue)];
      for (final name in names.whereType<String>()) {
        final target = localTarget(file.absolute.uri, name);
        if (target == null) continue;
        final imported = relative(target);
        edges.add(imported);
        if (!File.fromUri(target).existsSync()) violations.add('$path: missing $imported');
        if (path.startsWith('core/') &&
            (imported.startsWith('app/') || imported.startsWith('features/'))) {
          violations.add('$path: core must not depend on $imported');
        }
        if (path.contains('/data/') && imported.contains('/presentation/')) {
          violations.add('$path: DTO/adapter depends on $imported');
        }
        final feature = RegExp(r'^features/([^/]+)/').firstMatch(path)?[1];
        final other = RegExp(r'^features/([^/]+)/presentation/(screens|widgets|models)/')
            .firstMatch(imported);
        if (feature != null && other != null && other[1] != feature) {
          violations.add('$path: private presentation of another feature ($imported)');
        }
        if ((path.contains('/screens/') || path.contains('/widgets/')) &&
            imported.contains('/data/repositories/')) {
          violations.add('$path: UI imports a repository ($imported)');
        }
      }
    }
  }

  final done = <String>{};
  final visiting = <String>[];
  void visit(String path) {
    if (done.contains(path)) return;
    final start = visiting.indexOf(path);
    if (start >= 0) {
      violations.add('Dependency cycle: ${[...visiting.skip(start), path].join(' → ')}');
      return;
    }
    visiting.add(path);
    for (final target in graph[path] ?? <String>{}) {
      visit(target);
    }
    visiting.removeLast();
    done.add(path);
  }
  for (final path in graph.keys) { visit(path); }
  return violations;
}
