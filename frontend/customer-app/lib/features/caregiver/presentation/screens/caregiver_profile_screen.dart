import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_stats_row.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_stat_item.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_skills_section.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_bio_section.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_schedule_section.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_bottom_bar.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileScreen extends ConsumerWidget {
  final String id;

  const CaregiverProfileScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregiverAsync = ref.watch(caregiverDetailProvider(id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: caregiverAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (caregiver) {
          if (caregiver == null) {
            return const Center(
              child: Text('Không tìm thấy hồ sơ người chăm sóc'),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildHeader(context, caregiver),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeSlideStaggered(
                      index: 0,
                      child: _buildStatsRow(caregiver),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    FadeSlideStaggered(
                      index: 1,
                      child: _buildSection('Kỹ năng & Chuyên môn',
                          _buildSkillsSection(caregiver)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideStaggered(
                      index: 2,
                      child: _buildSection(
                          'Giới thiệu', _buildBioSection(caregiver)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideStaggered(
                      index: 3,
                      child: _buildSection(
                          'Lịch làm việc', _buildScheduleSection()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: caregiverAsync.maybeWhen(
        data: (caregiver) {
          return caregiver == null
              ? const SizedBox.shrink()
              : _buildBottomBar(context, caregiver);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CaregiverModel caregiver) =>
      CaregiverProfileHeader(caregiver: caregiver);

  Widget _buildStatsRow(CaregiverModel caregiver) => CaregiverProfileStatsRow(
      buildStatItem: _buildStatItem,
      caregiver: caregiver,
      buildDivider: _buildDivider);

  Widget _buildStatItem(String value, String label) =>
      CaregiverProfileStatItem(value: value, label: label);

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.control),
        content,
      ],
    );
  }

  Widget _buildSkillsSection(CaregiverModel caregiver) =>
      CaregiverProfileSkillsSection(caregiver: caregiver);

  Widget _buildBioSection(CaregiverModel caregiver) =>
      CaregiverProfileBioSection(caregiver: caregiver);

  Widget _buildScheduleSection() => const CaregiverProfileScheduleSection();

  Widget _buildBottomBar(BuildContext context, CaregiverModel caregiver) =>
      CaregiverProfileBottomBar(caregiver: caregiver);
}

// ── Favorite toggle button ─────────────────────────────
