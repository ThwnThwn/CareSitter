import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationPhoneField extends StatelessWidget {
  const RegistrationPhoneField(
      {super.key,
      required this.buildField,
      required this.phoneCtrl,
      required this.validatePhone});
  final Widget Function(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      List<TextInputFormatter>? inputFormatters,
      TextInputType? keyboardType,
      required String label,
      Widget? prefixWidget,
      TextCapitalization textCapitalization,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildField;
  final TextEditingController phoneCtrl;
  final String? Function(String?) validatePhone;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 4,
        child: buildField(
          controller: phoneCtrl,
          label: 'Số điện thoại',
          hint: '0901 234 567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: validatePhone,
          textInputAction: TextInputAction.next,
          prefixWidget: Container(
            margin: const EdgeInsets.only(right: AppSpacing.tight),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '🇻🇳 +84',
              style: TextStyle(
                  fontSize: AppFontSizes.s11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
}
