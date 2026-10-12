import 'package:caresitter_customer/features/settings/presentation/widgets/verified_address_field_suggestions_select_suggestion_fields.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/verified_address_field_fields.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/verified_address_selection.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
export 'package:caresitter_customer/features/settings/presentation/widgets/verified_address_selection.dart';

class VerifiedAddressField extends ConsumerStatefulWidget {
  final String? labelText;
  final String? hintText;
  final ValueChanged<VerifiedAddressSelection?> onChanged;

  const VerifiedAddressField({
    super.key,
    this.labelText,
    this.hintText,
    required this.onChanged,
  });

  @override
  ConsumerState<VerifiedAddressField> createState() =>
      _VerifiedAddressFieldState();
}

class _VerifiedAddressFieldState extends ConsumerState<VerifiedAddressField> {
  static const _uuid = Uuid();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _sessionToken = _uuid.v4();
  List<PlaceSuggestionModel> _suggestions = const [];
  VerifiedAddressSelection? _selection;
  bool _loading = false;
  bool _resolving = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_selection != null && value != _selection!.details.formattedAddress) {
      _selection = null;
      widget.onChanged(null);
    }

    _debounce?.cancel();
    final input = value.trim();
    if (input.length < 3) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadSuggestions(input);
    });
  }

  Future<void> _loadSuggestions(String input) async {
    if (!mounted) return;
    final requestVersion = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final suggestions =
          await ref.read(addressStoreProvider.notifier).autocompletePlaces(
                input: input,
                sessionToken: _sessionToken,
              );
      if (!mounted ||
          requestVersion != _requestVersion ||
          input != _controller.text.trim()) {
        return;
      }
      setState(() => _suggestions = suggestions);
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _suggestions = const [];
        _error = 'Không tìm được địa chỉ. Vui lòng thử lại.';
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestionModel suggestion) async {
    if (!mounted) return;
    _requestVersion++;
    setState(() {
      _resolving = true;
      _error = null;
    });

    try {
      final details =
          await ref.read(addressStoreProvider.notifier).getPlaceDetails(
                placeId: suggestion.placeId,
                sessionToken: _sessionToken,
              );
      if (!mounted) return;
      final selection = VerifiedAddressSelection(
        suggestion: suggestion,
        details: details,
        sessionToken: _sessionToken,
      );
      setState(() {
        _selection = selection;
        _controller.text = details.formattedAddress;
        _suggestions = const [];
        _sessionToken = _uuid.v4();
      });
      widget.onChanged(selection);
      _focusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selection = null;
        _error = 'Địa chỉ này chưa xác minh được. Chọn địa chỉ khác.';
      });
      widget.onChanged(null);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVerifiedSelection = _selection != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onTextChanged,
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'Địa chỉ chăm sóc',
            hintText: widget.hintText ?? 'Nhập số nhà, đường, phường...',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _resolving
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.inset),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasVerifiedSelection
                    ? const Icon(Icons.verified, color: AppColors.primary)
                    : null,
            errorText: _error ?? (hasVerifiedSelection ? null : null),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Đang tìm địa chỉ...',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
            ),
          ),
        if (!_loading &&
            _controller.text.trim().length >= 3 &&
            _suggestions.isEmpty &&
            _selection == null &&
            _error == null)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Không có gợi ý phù hợp.',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: AppFontSizes.s12),
            ),
          ),
        if (_suggestions.isNotEmpty)
          VerifiedAddressFieldSuggestionsSelectSuggestionFields(
              suggestions: _suggestions, selectSuggestion: _selectSuggestion),
        if (hasVerifiedSelection) const VerifiedAddressFieldFields(),
      ],
    );
  }
}
