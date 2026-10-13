import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../widgets/registration_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Đăng ký Caregiver'),
            leading: const AppBackButton(fallbackRoute: '/auth/phone')),
        body: SafeArea(
            top: false,
            child: RegistrationForm(onRegistered: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Đăng ký thành công. Bạn có thể đăng nhập ngay.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ));
              context.go('/auth/phone');
            })),
      );
}
