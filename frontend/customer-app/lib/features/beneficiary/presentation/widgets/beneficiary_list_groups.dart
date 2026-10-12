import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryListGroups extends StatelessWidget {
  const BeneficiaryListGroups(
      {super.key,
      required this.beneficiaries,
      required this.buildBeneficiaryCard});
  final List<BeneficiaryModel> beneficiaries;
  final Widget Function(BeneficiaryModel, BuildContext) buildBeneficiaryCard;
  @override
  Widget build(BuildContext context) => ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
          children: [
            if (beneficiaries.any((b) => b.isSelf)) ...[
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.compact),
                  child: Text('Thông tin chăm sóc của tôi',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              buildBeneficiaryCard(
                  beneficiaries.firstWhere((b) => b.isSelf), context),
            ],
            const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.compact),
                child: Text('Người thân',
                    style: TextStyle(fontWeight: FontWeight.w700))),
            if (!beneficiaries.any((b) => !b.isSelf))
              const Text('Chưa có hồ sơ người thân.'),
            for (final b in beneficiaries.where((b) => !b.isSelf))
              Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.control),
                  child: buildBeneficiaryCard(b, context)),
          ]);
}
