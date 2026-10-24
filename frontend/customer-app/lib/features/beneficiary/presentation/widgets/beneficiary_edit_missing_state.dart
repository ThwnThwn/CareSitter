import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';

class BeneficiaryEditMissingState extends StatelessWidget {
  const BeneficiaryEditMissingState({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Chỉnh sửa hồ sơ'),
            leading:
                const AppBackButton(fallbackRoute: AppRoutes.beneficiaries)),
        body: const Center(child: Text('Không tìm thấy hồ sơ người thân.')),
      );
}
