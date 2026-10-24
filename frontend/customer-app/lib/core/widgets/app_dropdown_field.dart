import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

part 'app_dropdown_field_menu.dart';

/// Shared select field styling for customer-app forms.
///
/// MenuAnchor keeps the popup attached below the field and outside scrollable
/// clipping, while FormField retains validation, saving and reset behavior.
class AppDropdownField<T> extends FormField<T> {
  AppDropdownField({
    super.key,
    required this.items,
    required this.onChanged,
    super.initialValue,
    this.decoration = const InputDecoration(),
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    super.enabled = true,
    this.isExpanded = true,
    this.itemHeight,
    this.menuMaxHeight = 320,
    this.selectedItemBuilder,
  })  : assert(itemHeight == null || itemHeight >= kMinInteractiveDimension),
        assert(menuMaxHeight > 0),
        super(
            builder: (field) =>
                (field as _AppDropdownFieldState<T>).buildDropdown());

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;
  final double? itemHeight;
  final double menuMaxHeight;
  final List<Widget> Function(BuildContext context)? selectedItemBuilder;

  @override
  FormFieldState<T> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends FormFieldState<T> {
  final MenuController _menuController = MenuController();
  final FocusNode _focusNode = FocusNode();

  AppDropdownField<T> get _field => widget as AppDropdownField<T>;

  bool get _isEnabled =>
      _field.enabled && _field.onChanged != null && _field.items.isNotEmpty;

  @override
  void didUpdateWidget(covariant AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
    if (!_isEnabled && _menuController.isOpen) {
      _menuController.close();
    }
  }

  @override
  void reset() {
    super.reset();
    _field.onChanged?.call(value);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget buildDropdown() {
    final theme = Theme.of(context);
    final fieldStyle = theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final menuStyle = theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ) ??
        const TextStyle(color: AppColors.textSecondary);
    final selectedIndex =
        _field.items.indexWhere((item) => item.value == value);
    final selectedItems = _field.selectedItemBuilder?.call(context);
    final selectedChild = selectedIndex < 0
        ? null
        : selectedItems != null && selectedItems.length == _field.items.length
            ? selectedItems[selectedIndex]
            : _field.items[selectedIndex].child;
    final decoration = _fieldDecoration(theme, _isEnabled)
        .copyWith(errorText: errorText ?? _field.decoration.errorText);
    final hint = decoration.hintText;

    return _DropdownMenu<T>(
      controller: _menuController,
      focusNode: _focusNode,
      items: _field.items,
      isEnabled: _isEnabled,
      isExpanded: _field.isExpanded,
      itemHeight: _field.itemHeight,
      menuMaxHeight: _field.menuMaxHeight,
      selectedChild: selectedChild,
      hint: hint,
      decoration: decoration,
      fieldStyle: fieldStyle,
      menuStyle: menuStyle,
      onSelected: (item) {
        didChange(item.value);
        _field.onChanged?.call(item.value);
        _menuController.close();
      },
      onMenuChanged: () => setState(() {}),
    );
  }

  InputDecoration _fieldDecoration(ThemeData theme, bool isEnabled) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: const BorderSide(color: AppColors.error),
    );
    final focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    );

    return _field.decoration.applyDefaults(theme.inputDecorationTheme).copyWith(
          enabled: isEnabled,
          filled: true,
          fillColor: isEnabled ? AppColors.surface : AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.inset,
          ),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: focusedBorder,
          errorBorder: errorBorder,
          focusedErrorBorder: focusedErrorBorder,
        );
  }
}
