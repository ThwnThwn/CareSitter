import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../widgets/register_screen_app_bar.dart';
import '../widgets/register_screen_title.dart';
import '../widgets/registration_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: FadeSlideStaggered(
                  index: 0,
                  slideFromTop: true,
                  child: RegisterScreenAppBar(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.section, 0,
                    AppSpacing.section, AppSpacing.formBottom),
                sliver: SliverList.list(children: [
                  const FadeSlideStaggered(index: 1, child: RegisterScreenTitle()),
                  RegistrationForm(onRegistered: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Đăng ký tài khoản thành công! Vui lòng đăng nhập.'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ));
                    context.go(AppRoutes.login);
                  }),
                ]),
              ),
            ],
          ),
        ),
      );
}
