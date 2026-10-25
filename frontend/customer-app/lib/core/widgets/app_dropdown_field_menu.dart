part of 'app_dropdown_field.dart';

class _DropdownMenu<T> extends StatelessWidget {
  const _DropdownMenu({
    required this.controller,
    required this.focusNode,
    required this.items,
    required this.isEnabled,
    required this.isExpanded,
    required this.itemHeight,
    required this.menuMaxHeight,
    required this.selectedChild,
    required this.hint,
    required this.decoration,
    required this.fieldStyle,
    required this.menuStyle,
    required this.onSelected,
    required this.onMenuChanged,
  });

  final MenuController controller;
  final FocusNode focusNode;
  final List<DropdownMenuItem<T>> items;
  final bool isEnabled;
  final bool isExpanded;
  final double? itemHeight;
  final double menuMaxHeight;
  final Widget? selectedChild;
  final String? hint;
  final InputDecoration decoration;
  final TextStyle fieldStyle;
  final TextStyle menuStyle;
  final ValueChanged<DropdownMenuItem<T>> onSelected;
  final VoidCallback onMenuChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width - 2 * AppSpacing.md;
          return MenuAnchor(
            controller: controller,
            childFocusNode: focusNode,
            useRootOverlay: true,
            style: MenuStyle(
              alignment: AlignmentDirectional.bottomStart,
              backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
              surfaceTintColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              elevation: const WidgetStatePropertyAll(4),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.compact),
              )),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: WidgetStatePropertyAll(Size(width, 0)),
              maximumSize: WidgetStatePropertyAll(Size(width, menuMaxHeight)),
            ),
            onOpen: onMenuChanged,
            onClose: onMenuChanged,
            menuChildren: [
              for (var index = 0; index < items.length; index++)
                _DropdownOption<T>(
                  item: items[index],
                  width: width,
                  itemHeight: itemHeight,
                  menuStyle: menuStyle,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0
                        ? const Radius.circular(AppRadius.compact)
                        : Radius.zero,
                    bottom: index == items.length - 1
                        ? const Radius.circular(AppRadius.compact)
                        : Radius.zero,
                  ),
                  onSelected: onSelected,
                ),
            ],
            builder: (context, controller, child) => _DropdownTrigger(
              controller: controller,
              focusNode: focusNode,
              isEnabled: isEnabled,
              isExpanded: isExpanded,
              selectedChild: selectedChild,
              hint: hint,
              decoration: decoration,
              fieldStyle: fieldStyle,
              onFocusChanged: onMenuChanged,
            ),
          );
        },
      );
}

class _DropdownOption<T> extends StatelessWidget {
  const _DropdownOption({
    required this.item,
    required this.width,
    required this.itemHeight,
    required this.menuStyle,
    required this.borderRadius,
    required this.onSelected,
  });

  final DropdownMenuItem<T> item;
  final double width;
  final double? itemHeight;
  final TextStyle menuStyle;
  final BorderRadius borderRadius;
  final ValueChanged<DropdownMenuItem<T>> onSelected;

  @override
  Widget build(BuildContext context) => MenuItemButton(
        onPressed: item.enabled ? () => onSelected(item) : null,
        style: ButtonStyle(
          alignment: AlignmentDirectional.centerStart,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(width, itemHeight ?? kMinInteractiveDimension),
          ),
          maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: borderRadius),
          ),
        ),
        child: SizedBox(
          width: width - 2 * AppSpacing.md,
          child: DefaultTextStyle(
            style: menuStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            child: item.child,
          ),
        ),
      );
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.isExpanded,
    required this.selectedChild,
    required this.hint,
    required this.decoration,
    required this.fieldStyle,
    required this.onFocusChanged,
  });

  final MenuController controller;
  final FocusNode focusNode;
  final bool isEnabled;
  final bool isExpanded;
  final Widget? selectedChild;
  final String? hint;
  final InputDecoration decoration;
  final TextStyle fieldStyle;
  final VoidCallback onFocusChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: isEnabled,
        expanded: controller.isOpen,
        child: Material(
          type: MaterialType.transparency,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            focusNode: focusNode,
            onFocusChange: (_) => onFocusChanged(),
            onTap: isEnabled
                ? () =>
                    controller.isOpen ? controller.close() : controller.open()
                : null,
            child: InputDecorator(
              isFocused: focusNode.hasFocus || controller.isOpen,
              isEmpty: selectedChild == null && hint == null,
              decoration: decoration.copyWith(hintText: null),
              child: Row(
                mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (isExpanded)
                    Expanded(child: _selectedContent())
                  else
                    Flexible(child: _selectedContent()),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isEnabled
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _selectedContent() => Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: DefaultTextStyle(
          style: selectedChild == null
              ? fieldStyle.copyWith(color: AppColors.textHint)
              : fieldStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          child: selectedChild ?? Text(hint ?? ''),
        ),
      );
}
