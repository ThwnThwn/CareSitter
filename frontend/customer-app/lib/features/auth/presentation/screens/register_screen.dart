import 'package:caresitter_customer/features/auth/presentation/widgets/registration_content.dart';
import '../../domain/registration_rules.dart';
import '../controllers/registration_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_app_bar.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_title.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_error_banner.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_password_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_terms_row.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_register_button.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_login_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) => registrationName(value);
  String? _validateEmail(String? value) => registrationEmail(value);
  String? _validatePhone(String? value) => registrationPhone(value);
  String? _validatePassword(String? value) => registrationPassword(value);
  String? _validateConfirmPassword(String? value) =>
      registrationConfirmation(value, _passCtrl.text);
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(registrationControllerProvider.notifier)
        .submit(RegisterRequest(
            fullName: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            confirmPassword: _confirmPassCtrl.text,
            phone: _phoneCtrl.text.trim()));
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Đăng ký tài khoản thành công! Vui lòng đăng nhập.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4)));
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationContent(
        buildAppBar: _buildAppBar,
        buildTitle: _buildTitle,
        ref: ref,
        buildErrorBanner: _buildErrorBanner,
        formKey: _formKey,
        buildField: _buildField,
        nameCtrl: _nameCtrl,
        validateName: _validateName,
        emailCtrl: _emailCtrl,
        validateEmail: _validateEmail,
        phoneCtrl: _phoneCtrl,
        validatePhone: _validatePhone,
        buildPasswordField: _buildPasswordField,
        passCtrl: _passCtrl,
        obscurePass: _obscurePass,
        validatePassword: _validatePassword,
        confirmPassCtrl: _confirmPassCtrl,
        obscureConfirm: _obscureConfirm,
        validateConfirmPassword: _validateConfirmPassword,
        buildTermsRow: _buildTermsRow,
        buildRegisterButton: _buildRegisterButton,
        buildLoginLink: _buildLoginLink,
        callbackAction1: () => setState(() => _obscurePass = !_obscurePass),
        callbackAction2: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
        callbackAction3: (_) => _register());
  }

  Widget _buildAppBar() => const RegisterScreenAppBar();

  Widget _buildTitle() => const RegisterScreenTitle();

  Widget _buildErrorBanner(String message) =>
      RegisterScreenErrorBanner(message: message);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? prefixWidget,
  }) =>
      RegisterScreenField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          label: label,
          hint: hint,
          prefixWidget: prefixWidget,
          icon: icon);

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) =>
      RegisterScreenPasswordField(
          controller: controller,
          obscure: obscure,
          validator: validator,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          label: label,
          onToggle: onToggle);

  Widget _buildTermsRow() => RegisterScreenTermsRow(
      onChanged: (value) =>
          ref.read(registrationControllerProvider.notifier).setAgreement(value),
      agreedToTerms: ref.watch(registrationControllerProvider).agreed);

  Widget _buildRegisterButton() => RegisterScreenRegisterButton(
      isLoading: ref.watch(registrationControllerProvider).busy,
      register: _register);

  Widget _buildLoginLink() => const RegisterScreenLoginLink();
}
