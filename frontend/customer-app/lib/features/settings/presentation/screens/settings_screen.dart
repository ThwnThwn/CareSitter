import 'package:caresitter_customer/features/settings/presentation/widgets/settings_top_padding_profile_layout.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_flat_header.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_beneficiaries_section.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_section.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_logout_button.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final profile = ref.watch(profileStoreProvider);
    final bookings = ref.watch(bookingStoreProvider);
    final totalSpent = bookings
        .where((b) => b.status == 'completed')
        .fold(0.0, (sum, b) => sum + b.totalPrice);

    return SettingsTopPaddingProfileLayout(
        buildFlatHeader: _buildFlatHeader,
        ref: ref,
        topPadding: topPadding,
        buildProfileCard: _buildProfileCard,
        profile: profile,
        bookings: bookings,
        totalSpent: totalSpent,
        buildBeneficiariesSection: _buildBeneficiariesSection,
        buildSection: _buildSection,
        buildLogoutButton: _buildLogoutButton);
  }

  Widget _buildFlatHeader(
          BuildContext context, WidgetRef ref, double topPadding) =>
      SettingsFlatHeader(topPadding: topPadding);

  Widget _buildProfileCard(BuildContext context, WidgetRef ref,
          UserProfile profile, int bookingCount, double totalSpent) =>
      SettingsProfileCard(
          profile: profile,
          bookingCount: bookingCount,
          formatCurrency: _formatCurrency,
          totalSpent: totalSpent);

  Widget _buildBeneficiariesSection(BuildContext context, WidgetRef ref) =>
      const SettingsBeneficiariesSection();

  Widget _buildSection(String title, List<Widget> items) =>
      SettingsSection(title: title, items: items);

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) =>
      SettingsLogoutButton(ref: ref);

  String _formatCurrency(double amount) {
    return formatVnd(amount, suffix: 'đ đã chi');
  }
}
