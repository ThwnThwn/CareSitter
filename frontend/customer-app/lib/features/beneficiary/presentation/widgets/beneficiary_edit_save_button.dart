import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';

class BeneficiaryEditSaveButton extends StatelessWidget {
  const BeneficiaryEditSaveButton(
      {super.key, required this.formController, required this.save});
  final BeneficiaryFormController formController;
  final Future<void> Function() save;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: formController.value.saving ? null : save,
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
        child: formController.value.saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Text('Lưu thay đổi',
                style: TextStyle(fontSize: AppFontSizes.s15)),
      );
}
