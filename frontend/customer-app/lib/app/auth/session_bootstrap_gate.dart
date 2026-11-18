import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/theme/app_theme.dart';

/// Keep the incoming route untouched until persisted credentials are checked.
class SessionBootstrapGate extends ConsumerWidget {
  const SessionBootstrapGate({super.key, required this.builder});
  final Widget Function(BuildContext, WidgetRef) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (!auth.isLoading && !auth.hasError) return builder(context, ref);
    return MaterialApp(
      key: const ValueKey('session-bootstrap'),
      title: 'CareSitter',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // A temporary Navigator would report '/' and replace web deep links.
      builder: (context, child) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (auth.isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Đang kiểm tra phiên đăng nhập…'),
                ] else ...[
                  const Text(
                    'Chưa kiểm tra được phiên đăng nhập. '
                    'Vui lòng kiểm tra kết nối và thử lại.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).retryRestore(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
