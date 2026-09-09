import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/address_repository.dart';

class VerifiedAddressSelection {
  final PlaceSuggestionModel suggestion;
  final VerifiedPlaceDetailsModel details;
  final String sessionToken;

  const VerifiedAddressSelection({
    required this.suggestion,
    required this.details,
    required this.sessionToken,
  });
}

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
          await ref.read(addressRepositoryProvider).autocompletePlaces(
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
      final details = await ref.read(addressRepositoryProvider).getPlaceDetails(
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
                    padding: EdgeInsets.all(14),
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
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Đang tìm địa chỉ...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        if (!_loading &&
            _controller.text.trim().length >= 3 &&
            _suggestions.isEmpty &&
            _selection == null &&
            _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Không có gợi ý phù hợp.',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _suggestions.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppColors.divider),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      title: Text(
                        _suggestions[i].mainText.isEmpty
                            ? _suggestions[i].description
                            : _suggestions[i].mainText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _suggestions[i].secondaryText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _selectSuggestion(_suggestions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (hasVerifiedSelection) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Đã xác minh vị trí từ Geoapify',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
