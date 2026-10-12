import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_search_ctrl_search_query_fields.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_fields.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_top_padding_has_location_panel.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_screen_caregiver_card.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_filtered_has_location_content.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_content_body.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/nearby_caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class CaregiverListScreen extends ConsumerStatefulWidget {
  const CaregiverListScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<CaregiverListScreen> createState() =>
      _CaregiverListScreenState();
}

class _CaregiverListScreenState extends ConsumerState<CaregiverListScreen> {
  bool _showAvailableOnly = false;
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery?.trim() ?? '';
    _searchCtrl = TextEditingController(text: _searchQuery);
  }

  List<CaregiverModel> _filtered(List<CaregiverModel> all) {
    var list = all;
    if (_showAvailableOnly) {
      list = list.where((c) => c.isOnline).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((c) =>
              c.displayName.toLowerCase().contains(q) ||
              c.skills.any((s) => s.toLowerCase().contains(q)) ||
              (c.location.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caregiverAsync = ref.watch(nearbyCaregiversProvider);
    final hasLocation =
        ref.watch(caregiverSearchAddressProvider).valueOrNull != null;
    final topPadding = MediaQuery.of(context).padding.top;
    final unreadCount = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: caregiverAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => SafeArea(
            child: CaregiverListFields(
                ref: ref,
                action1: () => ref.invalidate(addressStoreProvider),
                action2: (id) => ref
                    .read(caregiverSearchAddressIdProvider.notifier)
                    .state = id)),
        error: (e, _) => CaregiverListContentBody(ref: ref),
        data: (allCaregivers) {
          final filtered = _filtered(allCaregivers);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Flat header ──
              CaregiverListTopPaddingHasLocationPanel(
                  topPadding: topPadding,
                  hasLocation: hasLocation,
                  allCaregivers: allCaregivers,
                  unreadCount: unreadCount),

              // ── Search + chips ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                    AppSpacing.compact, AppSpacing.md, AppSpacing.inset),
                child: CaregiverListSearchCtrlSearchQueryFields(
                    ref: ref,
                    searchCtrl: _searchCtrl,
                    searchQuery: _searchQuery,
                    showAvailableOnly: _showAvailableOnly,
                    callbackAction1: () => ref.invalidate(addressStoreProvider),
                    callbackAction2: (id) => ref
                        .read(caregiverSearchAddressIdProvider.notifier)
                        .state = id,
                    callbackAction3: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    callbackAction4: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    callbackAction5: () =>
                        setState(() => _showAvailableOnly = false),
                    callbackAction6: () => setState(
                        () => _showAvailableOnly = !_showAvailableOnly)),
              ),
              const Divider(height: 1, color: AppColors.divider),

              // ── List ──
              CaregiverListFilteredHasLocationContent(
                  filtered: filtered,
                  hasLocation: hasLocation,
                  allCaregivers: allCaregivers,
                  buildCaregiverCard: _buildCaregiverCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCaregiverCard(CaregiverModel caregiver, BuildContext context) =>
      CaregiverListScreenCaregiverCard(
          caregiver: caregiver, formatCurrency: _formatCurrency);

  String _formatCurrency(double amount) {
    return formatVnd(amount);
  }
}

// ── Filter Chip Widget ────────────────────────────────────────────────
