import 'package:caresitter_customer/features/settings/presentation/widgets/change_password_form_key_old_pass_ctrl_form.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
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

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

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
    setState(() => _isSaving = true);

    String? errorMsg;
    try {
      final changed = await ref.read(passwordControllerProvider).changePassword(
            currentPassword: _oldPassCtrl.text,
            newPassword: _newPassCtrl.text,
          );
      if (changed) {
        // Đổi thành công → logout → về login
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đổi mật khẩu thành công! Vui lòng đăng nhập lại.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        await ref.read(authStateProvider.notifier).logout();
        return;
      }
    } on AppApiException catch (e) {
      final apiError = e;
      errorMsg = apiError.message;
    } catch (_) {
      errorMsg = 'Không thể đổi mật khẩu. Vui lòng thử lại.';
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (errorMsg != null && mounted) {
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
        body: ChangePasswordFormKeyOldPassCtrlForm(
            formKey: _formKey,
            buildLabel: _buildLabel,
            buildPasswordField: _buildPasswordField,
            oldPassCtrl: _oldPassCtrl,
            obscureOld: _obscureOld,
            newPassCtrl: _newPassCtrl,
            obscureNew: _obscureNew,
            confirmPassCtrl: _confirmPassCtrl,
            obscureConfirm: _obscureConfirm,
            isSaving: _isSaving,
            submit: _submit,
            callbackAction1: () => setState(() => _obscureOld = !_obscureOld),
            callbackAction2: (v) =>
                (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu cũ' : null,
            callbackAction3: () => setState(() => _obscureNew = !_obscureNew),
            callbackAction4: (v) {
              if (v == null || v.isEmpty) {
                return 'Vui lòng nhập mật khẩu mới';
              }
              if (v.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
              return null;
            },
            callbackAction5: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            callbackAction6: (v) {
              if (v == null || v.isEmpty) {
                return 'Vui lòng xác nhận mật khẩu';
              }
              if (v != _newPassCtrl.text) {
                return 'Mật khẩu xác nhận không khớp';
              }
              return null;
            }),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppFontSizes.s14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20),
          onPressed: onToggle,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
