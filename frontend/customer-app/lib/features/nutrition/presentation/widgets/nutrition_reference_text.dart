import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NutritionReferenceText extends StatelessWidget {
  const NutritionReferenceText(this.reference, {super.key, this.label});

  final String reference;
  final String? label;

  static Uri? webUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final uri = webUri(reference);
    if (uri == null) {
      return Text(reference, style: Theme.of(context).textTheme.bodySmall);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          try {
            if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              return;
            }
          } catch (_) {
            // The same message covers missing browsers and platform failures.
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không mở được liên kết nguồn.')),
            );
          }
        },
        child: Text(
          label ?? reference,
          softWrap: true,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
        ),
      ),
    );
  }
}
