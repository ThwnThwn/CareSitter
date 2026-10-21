import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.profile,
    required this.bookingCount,
    required this.totalSpent,
  });

  final UserProfile profile;
  final int bookingCount;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final contacts = [
      if (profile.phone.isNotEmpty) profile.phone,
      if (profile.email.isNotEmpty) profile.email,
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryContainer),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        const _ProfileGlow(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _ProfileAvatar(profile: profile),
            const SizedBox(height: 14),
            _ProfileIdentity(profile: profile, contacts: contacts),
            const SizedBox(height: 18),
            _ProfileStats(bookingCount: bookingCount, totalSpent: totalSpent),
            const SizedBox(height: 16),
            const _EditProfileButton(),
          ]),
        ),
      ]),
    );
  }
}

class _ProfileGlow extends StatelessWidget {
  const _ProfileGlow();
  @override
  Widget build(BuildContext context) => Positioned(
        top: -24,
        left: 0,
        right: 0,
        height: 60,
        child: Center(
          child: Container(
            width: 180,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});
  final UserProfile profile;

  String get initials => profile.name.trim().isNotEmpty
      ? profile.name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase())
          .take(2)
          .join()
      : 'U';

  @override
  Widget build(BuildContext context) {
    final hasAvatar = profile.avatarUrl?.isNotEmpty ?? false;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          border: Border.all(color: AppColors.primaryContainer, width: 4),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8)],
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  profile.avatarUrl!,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Initials(initials),
                )
              : _Initials(initials),
        ),
      ),
      const Positioned(bottom: 0, right: 0, child: _CameraButton()),
    ]);
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primaryContainer,
        alignment: Alignment.center,
        child: Text(value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            )),
      );
}

class _CameraButton extends StatelessWidget {
  const _CameraButton();
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/settings/profile/edit'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 6)
              ],
            ),
            child: const Icon(Icons.camera_alt,
                size: 15, color: AppColors.onPrimary),
          ),
        ),
      );
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.profile, required this.contacts});
  final UserProfile profile;
  final List<String> contacts;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(
          profile.name.isNotEmpty ? profile.name : 'Người dùng',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            contacts.join('  •  '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ]);
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.bookingCount, required this.totalSpent});
  final int bookingCount;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final booking = _Stat(
      label: 'LỊCH ĐÃ ĐẶT',
      value: '$bookingCount ca',
      icon: Icons.calendar_month_outlined,
    );
    final spending =
        _Stat(label: 'TỔNG CHI TIÊU', value: formatVnd(totalSpent));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryContainer),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        if (largeText || constraints.maxWidth < 250) {
          return Column(children: [
            booking,
            const Divider(color: AppColors.border),
            spending,
          ]);
        }
        return Row(children: [
          Expanded(child: booking),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(child: spending),
        ]);
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            if (icon != null) Icon(icon, size: 16, color: AppColors.primary),
            Text(value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ]);
}

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/settings/profile/edit'),
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Chỉnh sửa hồ sơ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
