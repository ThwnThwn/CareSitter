import '../widgets/change_password_form.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/password_controller.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool get _hasUnsavedChanges =>
      _oldPassCtrl.text.isNotEmpty ||
      _newPassCtrl.text.isNotEmpty ||
      _confirmPassCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(passwordControllerProvider.notifier);
    if (ref.read(passwordControllerProvider)) return;
    final auth = ref.read(authStateProvider.notifier);
    final generation = auth.sessionGeneration;

    String? errorMsg;
    try {
      final changed = await controller.changePassword(
        currentPassword: _oldPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      if (changed) {
        // Đổi thành công → logout → về login
        if (!mounted || !controller.isCurrent) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đổi mật khẩu thành công! Vui lòng đăng nhập lại.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted ||
            !controller.isCurrent ||
            auth.sessionGeneration != generation) {
          return;
        }
        await auth.logout();
        return;
      }
    } on AppApiException catch (e) {
      final apiError = e;
      errorMsg = apiError.message;
    } catch (_) {
      errorMsg = 'Không thể đổi mật khẩu. Vui lòng thử lại.';
    }

    if (errorMsg != null && mounted && controller.isCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      fallbackRoute: '/settings',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Đổi mật khẩu'),
          leading: AppBackButton(
            fallbackRoute: '/settings',
            onPressed: requestExit,
          ),
        ),
        body: ChangePasswordForm(
            formKey: _formKey,
            oldPassCtrl: _oldPassCtrl,
            newPassCtrl: _newPassCtrl,
            confirmPassCtrl: _confirmPassCtrl,
            isSaving: ref.watch(passwordControllerProvider),
            onSubmit: _submit),
      ),
    );
  }
}
