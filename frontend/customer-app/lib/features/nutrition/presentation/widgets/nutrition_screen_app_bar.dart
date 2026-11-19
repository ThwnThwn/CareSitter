import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_tab_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

enum NutritionScreenMenuAction { history, changeBeneficiary }

class NutritionScreenAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const NutritionScreenAppBar({
    super.key,
    this.inTab = false,
    required this.editing,
    required this.canReturnToMenu,
    required this.canReturnToBeneficiaries,
    required this.canEdit,
    required this.canOpenHistory,
    required this.canChangeBeneficiary,
    required this.onReturnToMenu,
    required this.onReturnToBeneficiaries,
    required this.onEdit,
    required this.onOpenHistory,
    required this.onChangeBeneficiary,
  });

  final bool inTab;
  final bool editing;
  final bool canReturnToMenu;
  final bool canReturnToBeneficiaries;
  final bool canEdit;
  final bool canOpenHistory;
  final bool canChangeBeneficiary;
  final VoidCallback onReturnToMenu;
  final VoidCallback onReturnToBeneficiaries;
  final VoidCallback onEdit;
  final VoidCallback onOpenHistory;
  final VoidCallback onChangeBeneficiary;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final hasMenu = canOpenHistory || canChangeBeneficiary;
    final title = editing ? 'Cập nhật dinh dưỡng' : 'Thực đơn dinh dưỡng';
    final leading = canReturnToMenu
        ? IconButton(
            tooltip: 'Quay lại thực đơn',
            onPressed: onReturnToMenu,
            icon: const Icon(Icons.arrow_back_rounded),
          )
        : canReturnToBeneficiaries
            ? IconButton(
                tooltip: 'Trở về chọn người',
                onPressed: onReturnToBeneficiaries,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null;
    final actions = <Widget>[
      IconButton(
        tooltip: 'Tra cứu tài liệu dinh dưỡng',
        color: AppColors.textHint,
        onPressed: () => context.push(AppRoutes.nutritionKnowledge),
        icon: const Icon(Icons.menu_book_outlined),
      ),
      if (canEdit)
        IconButton(
          tooltip: 'Cập nhật thông tin dinh dưỡng',
          color: AppColors.textHint,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
      if (hasMenu)
        PopupMenuButton<NutritionScreenMenuAction>(
          tooltip: 'Tùy chọn thực đơn',
          onSelected: (action) {
            switch (action) {
              case NutritionScreenMenuAction.history:
                onOpenHistory();
                break;
              case NutritionScreenMenuAction.changeBeneficiary:
                onChangeBeneficiary();
                break;
            }
          },
          itemBuilder: (context) => [
            if (canOpenHistory)
              const PopupMenuItem(
                value: NutritionScreenMenuAction.history,
                child: _MenuItem(
                  icon: Icons.history_rounded,
                  label: 'Thực đơn đã lưu',
                ),
              ),
            if (canChangeBeneficiary)
              const PopupMenuItem(
                value: NutritionScreenMenuAction.changeBeneficiary,
                child: _MenuItem(
                  icon: Icons.switch_account_outlined,
                  label: 'Đổi người',
                ),
              ),
          ],
        ),
    ];
    return inTab
        ? AppTabHeader(
            title: title,
            topPadding: MediaQuery.paddingOf(context).top,
            leading: leading,
            actions: actions,
          )
        : AppBar(
            centerTitle: false,
            title: Text(title),
            leading: leading,
            actions: actions,
          );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.compact),
          Text(label),
        ],
      );
}
