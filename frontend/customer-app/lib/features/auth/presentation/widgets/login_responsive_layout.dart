import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'login_hero_tokens.dart';
import 'auth_hero_header.dart';
import 'login_hero_section.dart';

class LoginResponsiveLayout extends StatelessWidget {
  const LoginResponsiveLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.wideAuthLayout &&
            constraints.maxHeight >= AppBreakpoints.wideAuthMinHeight;
        if (wide) {
          return SafeArea(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Expanded(flex: 5, child: AuthHeroHeader(expanded: true)),
                Expanded(
                    flex: 6,
                    child: ColoredBox(
                      color: LoginHeroTokens.background,
                      child: LayoutBuilder(
                          builder: (context, formConstraints) =>
                              SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                      minHeight: formConstraints.maxHeight),
                                  child: Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth:
                                                  AppLayout.authFormMaxWidth),
                                          child: child)),
                                ),
                              )),
                    )),
              ]));
        }
        return SafeArea(
            top: false,
            child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [const LoginHeroSection(), child])));
      });
}
