import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void popOrGo(BuildContext context, {required String fallbackRoute}) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  final currentPath = GoRouterState.of(context).uri.path;
  if (currentPath != fallbackRoute) {
    context.go(fallbackRoute);
  }
}

typedef DiscardChangesBuilder = Widget Function(
  BuildContext context,
  VoidCallback requestExit,
);
