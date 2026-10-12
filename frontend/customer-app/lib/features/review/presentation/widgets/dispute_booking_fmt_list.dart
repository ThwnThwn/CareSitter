import 'package:caresitter_customer/features/review/presentation/widgets/dispute_attachments_row.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_desc_ctrl_content.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_booking_fmt_panel.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_selected_reason_desc_ctrl_button.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_attachments_pick_image_row.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_panel.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_attachments_control.dart';
import 'package:caresitter_customer/features/review/presentation/widgets/dispute_reason_is_selected_content.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class DisputeBookingFmtList extends StatelessWidget {
  const DisputeBookingFmtList(
      {super.key,
      required this.refRow,
      required this.bk,
      required this.fmt,
      required this.reasons,
      required this.selectedReason,
      required this.descCtrl,
      required this.attachments,
      required this.pickImage,
      required this.pickVideo,
      required this.setState,
      required this.isSubmitting,
      required this.submit,
      required this.callbackAction1,
      required this.callbackAction2});
  final Widget Function(String, String) refRow;
  final BookingModel bk;
  final String Function(double) fmt;
  final List<String> reasons;
  final String? selectedReason;
  final TextEditingController descCtrl;
  final List<XFile> attachments;
  final Future<void> Function() pickImage;
  final Future<void> Function() pickVideo;
  final void Function(void Function()) setState;
  final bool isSubmitting;
  final Future<void> Function() submit;
  final void Function(String) callbackAction1;
  final void Function(String) callbackAction2;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Warning banner
          const DisputePanel(),
          const SizedBox(height: AppSpacing.md),

          // Booking reference
          DisputeBookingFmtPanel(refRow: refRow, bk: bk, fmt: fmt),
          const SizedBox(height: AppSpacing.section),

          // Reason selection
          const Text('Lý do khiếu nại *',
              style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.control),
          ...reasons.map((r) {
            final isSelected = r == selectedReason;
            return DisputeReasonIsSelectedContent(
                onSelected: callbackAction1, r: r, isSelected: isSelected);
          }),
          const SizedBox(height: AppSpacing.md),

          // Description
          const Text('Mô tả chi tiết *',
              style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          DisputeDescCtrlContent(
              descCtrl: descCtrl, callbackAction2: callbackAction2),
          const SizedBox(height: AppSpacing.md),

          // Attachments
          DisputeAttachmentsRow(attachments: attachments),
          const SizedBox(height: AppSpacing.sm),
          DisputeAttachmentsPickImageRow(
              attachments: attachments,
              pickImage: pickImage,
              pickVideo: pickVideo),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.compact),
            DisputeAttachmentsControl(
                attachments: attachments, setState: setState),
          ],
          const SizedBox(height: AppSpacing.lg),
          DisputeSelectedReasonDescCtrlButton(
              selectedReason: selectedReason,
              descCtrl: descCtrl,
              isSubmitting: isSubmitting,
              submit: submit),
          const SizedBox(height: AppSpacing.sm),
          Center(
              child: Text(
            descCtrl.text.length < 20 ? 'Vui lòng mô tả ít nhất 20 ký tự' : '',
            style: const TextStyle(
                fontSize: AppFontSizes.s12, color: AppColors.textHint),
          )),
          const SizedBox(height: AppSpacing.xl),
        ],
      );
}
