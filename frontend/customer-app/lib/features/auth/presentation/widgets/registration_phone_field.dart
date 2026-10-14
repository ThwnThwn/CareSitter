import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../../domain/registration_rules.dart';
import 'register_screen_field.dart';

class RegistrationPhoneField extends StatelessWidget {
  const RegistrationPhoneField(
      {super.key, required this.controller, required this.enabled});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 4,
        child: RegisterScreenField(
          controller: controller,
          enabled: enabled,
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: registrationPhone,
          textInputAction: TextInputAction.next,
          prefixWidget: Container(
            margin: const EdgeInsets.only(right: AppSpacing.tight),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.checkbox),
            ),
            child: const Text(
              '🇻🇳 +84',
              style:
                  TextStyle(fontSize: AppFontSizes.s11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
}
