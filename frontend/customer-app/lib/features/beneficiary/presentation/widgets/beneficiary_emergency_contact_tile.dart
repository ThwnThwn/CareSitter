import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryEmergencyContactTile extends StatelessWidget {
  const BeneficiaryEmergencyContactTile({super.key, required this.c});
  final EmergencyContact c;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          final uri = Uri(scheme: 'tel', path: c.phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gọi đến ${c.phone}')),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.compact),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                c.phone,
                style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
}
