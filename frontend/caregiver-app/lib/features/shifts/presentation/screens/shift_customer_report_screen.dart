import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_sliver_app_bar.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_caregiver_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_timeline.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_checklist.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_photo_gallery.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_note_card.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_share_button.dart';

class ShiftCustomerReportScreen extends StatefulWidget {
  final String bookingId;
  final String beneficiaryName;
  final String caregiverName;
  final double caregiverEarning;
  final int completedTasks;
  final int totalTasks;
  final String duration;
  final String checkInTime;
  final String checkOutTime;
  final String caregiverNote;
  final List<String> taskPhotos; // Cloudinary URLs

  const ShiftCustomerReportScreen({
    super.key,
    required this.bookingId,
    required this.beneficiaryName,
    required this.caregiverName,
    required this.caregiverEarning,
    required this.completedTasks,
    required this.totalTasks,
    required this.duration,
    required this.checkInTime,
    required this.checkOutTime,
    this.caregiverNote = '',
    this.taskPhotos = const [],
  });

  @override
  State<ShiftCustomerReportScreen> createState() =>
      _ShiftCustomerReportScreenState();
}

class _ShiftCustomerReportScreenState extends State<ShiftCustomerReportScreen> {
  void _onShare() {
    AppToast.success(context, 'Đã sao chép link báo cáo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          ReportSliverAppBar(
            beneficiaryName: widget.beneficiaryName,
            bookingId: widget.bookingId,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.section, 0, AppSpacing.section, AppSpacing.s40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.section),
                ReportCaregiverCard(
                  caregiverName: widget.caregiverName,
                  caregiverEarning: widget.caregiverEarning,
                ),
                const SizedBox(height: AppSpacing.section),
                ReportTimeline(
                  checkInTime: widget.checkInTime,
                  checkOutTime: widget.checkOutTime,
                  duration: widget.duration,
                ),
                const SizedBox(height: AppSpacing.section),
                ReportChecklist(
                  completedTasks: widget.completedTasks,
                  totalTasks: widget.totalTasks,
                  taskPhotos: widget.taskPhotos,
                ),
                const SizedBox(height: AppSpacing.section),
                ReportPhotoGallery(taskPhotos: widget.taskPhotos),
                if (widget.caregiverNote.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.section),
                  ReportNoteCard(caregiverNote: widget.caregiverNote),
                ],
                const SizedBox(height: AppSpacing.wide),
                ReportShareButton(onShare: _onShare),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
