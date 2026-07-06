import 'dart:async';

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

class AppBackButton extends StatelessWidget {
  final String fallbackRoute;
  final Color? color;
  final VoidCallback? onPressed;

  const AppBackButton({
    super.key,
    required this.fallbackRoute,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BackButton(
      color: color,
      onPressed:
          onPressed ?? () => popOrGo(context, fallbackRoute: fallbackRoute),
    );
  }
}

class AppCloseButton extends StatelessWidget {
  final String fallbackRoute;
  final Color? color;
  final VoidCallback? onPressed;

  const AppCloseButton({
    super.key,
    required this.fallbackRoute,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CloseButton(
      color: color,
      onPressed:
          onPressed ?? () => popOrGo(context, fallbackRoute: fallbackRoute),
    );
  }
}

typedef DiscardChangesBuilder = Widget Function(
  BuildContext context,
  VoidCallback requestExit,
);

class DiscardChangesGuard extends StatefulWidget {
  final bool Function() hasChanges;
  final String fallbackRoute;
  final DiscardChangesBuilder builder;
  final String title;
  final String message;

  const DiscardChangesGuard({
    super.key,
    required this.hasChanges,
    required this.fallbackRoute,
    required this.builder,
    this.title = 'Bỏ các thay đổi?',
    this.message =
        'Thông tin bạn vừa nhập chưa được lưu. Bạn có chắc muốn rời khỏi màn hình này?',
  });

  @override
  State<DiscardChangesGuard> createState() => _DiscardChangesGuardState();
}

class _DiscardChangesGuardState extends State<DiscardChangesGuard> {
  bool _allowPop = false;
  bool _isConfirming = false;

  Future<void> _requestExit() async {
    if (_isConfirming) return;

    if (!widget.hasChanges()) {
      _allowAndExit();
      return;
    }

    _isConfirming = true;
    final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(widget.title),
            content: Text(widget.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Tiếp tục chỉnh sửa'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Bỏ thay đổi'),
              ),
            ],
          ),
        ) ??
        false;
    _isConfirming = false;

    if (shouldDiscard && mounted) {
      _allowAndExit();
    }
  }

  void _allowAndExit() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        popOrGo(context, fallbackRoute: widget.fallbackRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_requestExit());
        }
      },
      child: widget.builder(
        context,
        () => unawaited(_requestExit()),
      ),
    );
  }
}
