import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/navigation_helpers.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/mock/mock_data.dart';
import '../../application/booking_store.dart';
import '../../../beneficiary/application/beneficiary_store.dart';
import '../../../catalog/application/service_store.dart';
import '../../../catalog/application/address_store.dart';
import '../../../catalog/data/models/service_model.dart';
import '../../../caregiver/application/caregiver_store.dart';
import '../../../caregiver/data/models/caregiver_model.dart';
import '../../../../core/api/dio_client.dart' show AppApiException;
import '../../../../core/presentation/widgets/fade_slide_staggered.dart';

class BookingWizardScreen extends ConsumerStatefulWidget {
  final String? initialServiceId;
  final String? initialBeneficiaryId;

  const BookingWizardScreen({
    super.key,
    this.initialServiceId,
    this.initialBeneficiaryId,
  });

  @override
  ConsumerState<BookingWizardScreen> createState() =>
      _BookingWizardScreenState();
}

class _BookingWizardScreenState extends ConsumerState<BookingWizardScreen> {
  int _currentStep = 0;
  String? _selectedServiceId;
  String? _selectedBeneficiaryId;
  String? _selectedCaregiverId;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  int _duration = 4; // hours
  bool _consentAccepted = false; // FR-CUS-09
  bool _isSystemMatched = true;
  bool _isSubmitting = false; // guard chống double-submit
  String _bookingMode = 'demo';
  String? _selectedAddressId; // ID địa chỉ thật từ API

  bool get _hasUnsavedChanges =>
      _selectedServiceId != widget.initialServiceId ||
      _selectedBeneficiaryId != widget.initialBeneficiaryId ||
      _selectedCaregiverId != null ||
      _selectedDate != null ||
      _startTime != null ||
      _selectedAddressId != null ||
      _duration != 4 ||
      _consentAccepted ||
      !_isSystemMatched ||
      _bookingMode != 'demo';

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.initialServiceId;
    _selectedBeneficiaryId = widget.initialBeneficiaryId;

    // Nếu có initialBeneficiaryId, auto-set địa chỉ mặc định và bỏ qua bước chọn người thân
    if (_selectedBeneficiaryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final all = ref.read(beneficiaryStoreProvider);
        try {
          final b = all.firstWhere((b) => b.id == _selectedBeneficiaryId);
          if (b.defaultAddressId != null) {
            setState(() => _selectedAddressId = b.defaultAddressId);
          }
        } catch (_) {
          // list chưa load xong hoặc không tìm thấy — bỏ qua, user có thể chọn địa chỉ thủ công
        }
      });
    }

    // Tính bước khởi đầu:
    // - Có cả service lẫn beneficiary → Bước 2 (Lịch & địa chỉ)
    // - Chỉ có beneficiary → Bước 0 (Dịch vụ) nhưng bước người thân đã pre-filled
    // - Chỉ có service → Bước 1 (Người thân)
    if (_selectedServiceId != null && _selectedBeneficiaryId != null) {
      _currentStep = 2;
    } else if (_selectedServiceId != null) {
      _currentStep = 1;
    }
    // nếu chỉ có beneficiaryId thì vẫn bắt đầu từ Bước 0 để chọn dịch vụ
  }

  @override
  void dispose() {
    super.dispose();
  }

  final List<String> _stepTitles = [
    'Dịch vụ',
    'Người thân',
    'Lịch & địa chỉ',
    'Chăm sóc viên',
    'Đồng ý',
    'Xác nhận'
  ];

  ServiceModel? get _selectedService {
    if (_selectedServiceId == null) return null;
    final servicesAsync = ref.read(serviceStoreProvider);
    final list = servicesAsync.valueOrNull ?? [];
    if (list.isEmpty) return null;
    return list.firstWhere((s) => s.id == _selectedServiceId,
        orElse: () => list.first);
  }

  MockBeneficiary? get _selectedBeneficiary {
    if (_selectedBeneficiaryId == null) return null;
    final all = ref.read(beneficiaryStoreProvider);
    if (all.isEmpty) return null;
    return all.firstWhere(
      (b) => b.id == _selectedBeneficiaryId,
      orElse: () => all.first,
    );
  }

  CaregiverModel? get _selectedCaregiver {
    if (_selectedCaregiverId == null) return null;
    final caregiverAsync = ref.read(caregiverStoreProvider);
    final list = caregiverAsync.valueOrNull ?? [];
    if (list.isEmpty) return null;
    return list.firstWhere((c) => c.id == _selectedCaregiverId,
        orElse: () => list.first);
  }

  bool get _hasValidSchedule {
    if (_selectedDate == null || _startTime == null) return false;
    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    return start.isAfter(DateTime.now().add(const Duration(minutes: 30)));
  }

  List<CaregiverModel> get _matchedCaregivers {
    // NOTE: chỉ dùng trong _buildCaregiverStep nơi ref.watch đã được gọi.
    // Getter này đọc cached value sau khi widget đã rebuild.
    final caregiverAsync = ref.read(caregiverStoreProvider);
    final all = caregiverAsync.valueOrNull ?? [];
    final candidates = all.where((c) => c.isOnline).toList();
    candidates
        .sort((a, b) => _matchScoreModel(b).compareTo(_matchScoreModel(a)));
    final serviceMatches =
        candidates.where((c) => _matchesServiceModel(c)).toList();
    return serviceMatches.isEmpty ? candidates : serviceMatches;
  }

  bool _matchesServiceModel(CaregiverModel caregiver) {
    final skills = caregiver.skills.join(' ').toLowerCase();
    final keywords = switch (_selectedServiceId) {
      _ => const <String>[],
    };
    return keywords.isEmpty || keywords.any(skills.contains);
  }

  int _matchScoreModel(CaregiverModel caregiver) {
    var score = _matchesServiceModel(caregiver) ? 100 : 0;
    score += (caregiver.ratingAvg * 10).round();
    return score;
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedServiceId != null;
      case 1:
        return _selectedBeneficiaryId != null;
      case 2:
        return _hasValidSchedule && _selectedAddressId != null;
      case 3:
        return _selectedCaregiverId != null || _isSystemMatched;
      case 4:
        return _consentAccepted;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      fallbackRoute: '/home',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Đặt lịch hỗ trợ'),
          backgroundColor: AppColors.cardBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: const Color(0x1A2F7F7F),
          leading: AppCloseButton(
            fallbackRoute: '/home',
            onPressed: requestExit,
          ),
        ),
        body: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FadeSlideStaggered(
                  key: ValueKey(_currentStep),
                  index: 0,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_stepTitles.length, (i) {
          final isDone = i < _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: i <= _currentStep
                                  ? AppColors.success
                                  : AppColors.divider,
                            ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.success
                            : (isCurrent
                                ? AppColors.primary
                                : AppColors.surfaceVariant),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : AppColors.textHint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      child: i == _stepTitles.length - 1
                          ? const SizedBox()
                          : Container(
                              height: 2,
                              color: i < _currentStep
                                  ? AppColors.success
                                  : AppColors.divider,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    _stepTitles[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isCurrent ? AppColors.primary : AppColors.textHint,
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceStep();
      case 1:
        return _buildBeneficiaryStep();
      case 2:
        return _buildTimeStep();
      case 3:
        return _buildCaregiverStep();
      case 4:
        return _buildConsentStep();
      case 5:
        return _buildConfirmStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildServiceStep() {
    final servicesAsync = ref.watch(serviceStoreProvider);
    return servicesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(child: Text('Lỗi tải dịch vụ: $e')),
      data: (services) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chọn dịch vụ cần đặt',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Chọn loại dịch vụ chăm sóc phù hợp',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ...services.map((s) {
            final isSelected = _selectedServiceId == s.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedServiceId = s.id;
                _selectedCaregiverId = null;
                _isSystemMatched = true;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: Text(s.icon,
                              style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${s.pricePerHour.toInt()}đ/giờ',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryStep() {
    final beneficiaries = ref.watch(beneficiaryStoreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Người được chăm sóc',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Chọn người thân cần được chăm sóc',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (widget.initialBeneficiaryId != null &&
            _selectedBeneficiary != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã chọn sẵn: ${_selectedBeneficiary!.name} — bạn có thể đổi sang người khác nếu muốn.',
                    style:
                        const TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...beneficiaries.map((b) {
          final isSelected = _selectedBeneficiaryId == b.id;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedBeneficiaryId = b.id;
              if (b.defaultAddressId != null) {
                _selectedAddressId = b.defaultAddressId;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(b.avatarInitial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('${b.age} tuổi • ${b.relation} • ${b.careLevel}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        Text(b.condition,
                            style: const TextStyle(
                                color: AppColors.textHint, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 22),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        // Nút thêm người thân mới từ trong wizard
        GestureDetector(
          onTap: () async {
            await context.push('/beneficiaries/create');
            // Sau khi pop về, beneficiaryStoreProvider đã cập nhật tự động
            // Nếu chưa chọn ai, tự chọn hồ sơ mới nhất
            if (_selectedBeneficiaryId == null && mounted) {
              final updated = ref.read(beneficiaryStoreProvider);
              final newOnes = updated
                  .where((b) => !const ['b001', 'b002', 'b003'].contains(b.id))
                  .toList();
              if (newOnes.isNotEmpty) {
                setState(() => _selectedBeneficiaryId = newOnes.last.id);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                  style: BorderStyle.solid),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_outlined,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('+ Thêm người thân mới',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverStep() {
    // ref.watch → widget tự rebuild khi caregiver store load xong
    final caregiverAsync = ref.watch(caregiverStoreProvider);

    return caregiverAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(child: Text('Lỗi tải danh sách: $e')),
      data: (_) {
        final available = _matchedCaregivers;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn người chăm sóc',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${available.length} chăm sóc viên phù hợp với dịch vụ, lịch và khu vực',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (available.isNotEmpty) ...[
              GestureDetector(
                onTap: () => setState(() {
                  _isSystemMatched = true;
                  // Không gán caregiverId cụ thể — backend tự match
                  _selectedCaregiverId = null;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isSystemMatched
                        ? AppColors.primaryContainer
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isSystemMatched
                          ? AppColors.primary
                          : AppColors.border,
                      width: _isSystemMatched ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Để hệ thống gợi ý',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              'Hệ thống sẽ chọn người phù hợp nhất cho bạn',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_isSystemMatched)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const Text(
                'Hoặc tự chọn chăm sóc viên',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
            ],
            ...available.map((c) {
              final isSelected = _selectedCaregiverId == c.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _isSystemMatched = false;
                  _selectedCaregiverId = c.id;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(c.initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (c.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(c.displayName,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600))),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 12, color: Color(0xFFF39C12)),
                                const SizedBox(width: 3),
                                Text(
                                    '${c.ratingAvg.toStringAsFixed(1)} • ${c.yearsOfExperience ?? 3} năm',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                            if (c.hourlyRateExpected != null)
                              Text('${c.hourlyRateExpected}đ/giờ',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 22),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _openAddressSelector() async {
    final selectedParam = _selectedAddressId == null
        ? ''
        : '&selected=${Uri.encodeComponent(_selectedAddressId!)}';
    final selectedAddressId = await context
        .push<String>('/settings/addresses?select=1$selectedParam');

    if (!mounted) return;
    ref.invalidate(addressStoreProvider);

    if (selectedAddressId == null || selectedAddressId.isEmpty) return;
    setState(() {
      _selectedAddressId = selectedAddressId;
      _selectedCaregiverId = null;
    });
  }

  Widget _buildTimeStep() {
    final addressAsync = ref.watch(addressStoreProvider);
    // Khi service thay doi, dat duration mac dinh theo service
    final defaultDurationHrs =
        (_selectedService?.defaultDurationMinutes ?? 240) ~/ 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn thời gian',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Chọn ngày và giờ bắt đầu ca chăm sóc',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        // Date picker
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme:
                      const ColorScheme.light(primary: AppColors.primary),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _selectedCaregiverId = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _selectedDate != null
                      ? AppColors.primary
                      : AppColors.border,
                  width: _selectedDate != null ? 2 : 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Chọn ngày...',
                    style: TextStyle(
                        color: _selectedDate != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        fontSize: 14),
                  ),
                ),
                if (_selectedDate != null)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 8, minute: 0),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme:
                        const ColorScheme.light(primary: AppColors.primary)),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _startTime = picked;
                _selectedCaregiverId = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                      _startTime != null ? AppColors.primary : AppColors.border,
                  width: _startTime != null ? 2 : 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _startTime != null
                        ? _startTime!.format(context)
                        : 'Chọn giờ bắt đầu...',
                    style: TextStyle(
                        color: _startTime != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        fontSize: 14),
                  ),
                ),
                if (_startTime != null)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
        if (_selectedDate != null &&
            _startTime != null &&
            !_hasValidSchedule) ...[
          const SizedBox(height: 8),
          const Text(
            'Thời gian bắt đầu phải sau hiện tại ít nhất 30 phút.',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Thời lượng (giờ)',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(
              '(mặc định: ${defaultDurationHrs}h)',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 2, 3, 4, 6, 8, 12].map((h) {
            final isSelected = _duration == h;
            final isDefault = h == defaultDurationHrs;
            return GestureDetector(
              onTap: () => setState(() => _duration = h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isDefault
                            ? AppColors.primaryLight
                            : AppColors.border,
                    width: isDefault && !isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? AppShadows.card : [],
                ),
                child: Center(
                  child: Text(
                    '$h',
                    style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        // ── Dia chi cham soc — lay tu API ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Địa chỉ chăm sóc',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: _openAddressSelector,
              icon: const Icon(Icons.location_on_outlined, size: 16),
              label: const Text('Chọn / thêm', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        addressAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Không tải được danh sách địa chỉ. Thử lại?',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(addressStoreProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (addresses) {
            if (addresses.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Bạn chưa có địa chỉ nào. Thêm ngay để đặt lịch.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAddressSelector,
                      child: const Text('Thêm'),
                    ),
                  ],
                ),
              );
            }
            // Auto-select địa chỉ mặc định của người thân nếu chưa chọn gì
            final defaultAddrId = _selectedBeneficiary?.defaultAddressId;
            if (_selectedAddressId == null && defaultAddrId != null) {
              final matched = addresses.any((a) => a.id == defaultAddrId);
              if (matched) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedAddressId == null) {
                    setState(() => _selectedAddressId = defaultAddrId);
                  }
                });
              }
            }

            final selectedAddress = _selectedAddressId == null
                ? null
                : _findAddressById(addresses, _selectedAddressId!);

            if (selectedAddress == null) {
              return _buildChooseAddressPrompt();
            }

            return _buildSelectedAddressCard(selectedAddress);
          },
        ),
        const SizedBox(height: 20),
        if (_selectedService != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ước tính chi phí:',
                    style: TextStyle(color: AppColors.primary, fontSize: 13)),
                Text(
                  '${(_selectedService!.pricePerHour * _duration).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}đ',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  AddressModel? _findAddressById(List<AddressModel> addresses, String id) {
    for (final address in addresses) {
      if (address.id == id) return address;
    }
    return null;
  }

  Widget _buildChooseAddressPrompt() {
    return InkWell(
      onTap: _openAddressSelector,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_on_outlined,
                color: AppColors.textSecondary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chọn địa chỉ chăm sóc',
                style: TextStyle(color: AppColors.textHint, fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedAddressCard(AddressModel address) {
    final isBeneficiaryDefault =
        _selectedBeneficiary?.defaultAddressId == address.id;

    return InkWell(
      onTap: _openAddressSelector,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.displayLabel,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isBeneficiaryDefault)
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _selectedBeneficiary == null
                                  ? 'Của người thân'
                                  : 'Của ${_selectedBeneficiary!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    address.shortAddress,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_outlined,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Điều khoản & Đồng ý',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text('Vui lòng đọc kỹ trước khi xác nhận đặt lịch',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Consent content (scrollable box)
        Container(
          height: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConsentSection(
                  '1. Cam kết dịch vụ',
                  'CareSitter cam kết cung cấp người chăm sóc đã được xác minh danh tính, kiểm tra lý lịch và đào tạo chuyên môn. Mọi caregiver phải tuân thủ quy tắc ứng xử nghiêm ngặt trong suốt ca làm việc.',
                ),
                _buildConsentSection(
                  '2. Trách nhiệm của khách hàng',
                  'Bạn cam kết cung cấp thông tin chính xác về người được chăm sóc, bao gồm nhu cầu hỗ trợ, sở thích sinh hoạt và các lưu ý đặc biệt. Thông tin sai lệch có thể ảnh hưởng đến chất lượng dịch vụ và CareSitter không chịu trách nhiệm trong trường hợp này.',
                ),
                _buildConsentSection(
                  '3. Quyền riêng tư & dữ liệu',
                  'Thông tin cá nhân của người được chăm sóc được bảo mật tuyệt đối theo Chính sách Bảo mật của CareSitter. Dữ liệu chỉ được chia sẻ với caregiver được phân công và các cơ quan có thẩm quyền khi cần thiết.',
                ),
                _buildConsentSection(
                  '4. Chính sách hủy & hoàn tiền',
                  'Hủy trước 24h: hoàn 100%. Hủy trước 12h: hoàn 50%. Hủy trong vòng 2h hoặc khi caregiver đã đến: không hoàn tiền. Trường hợp khẩn cấp sẽ được xem xét riêng.',
                ),
                _buildConsentSection(
                  '5. Xử lý sự cố',
                  'Trong trường hợp xảy ra sự cố trong ca chăm sóc, caregiver sẽ liên hệ ngay với các liên hệ khẩn cấp bạn đã cung cấp. CareSitter có đội hỗ trợ 24/7 để xử lý các tình huống khẩn cấp.',
                ),
                _buildConsentSection(
                  '6. Bồi thường',
                  'CareSitter có bảo hiểm trách nhiệm nghề nghiệp cho mọi ca làm việc. Trong trường hợp xảy ra thiệt hại do lỗi của caregiver, CareSitter sẽ hỗ trợ theo quy trình giải quyết khiếu nại.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Checkbox đồng ý
        GestureDetector(
          onTap: () => setState(() => _consentAccepted = !_consentAccepted),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _consentAccepted
                  ? AppColors.primaryContainer
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _consentAccepted ? AppColors.primary : AppColors.border,
                width: _consentAccepted ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _consentAccepted
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _consentAccepted
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: _consentAccepted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tôi đã đọc, hiểu và đồng ý với tất cả Điều khoản Dịch vụ và Chính sách Bảo mật của CareSitter. Tôi xác nhận rằng thông tin đã cung cấp là chính xác.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_consentAccepted) ...[
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textHint),
              SizedBox(width: 6),
              Text(
                'Bạn cần đồng ý với điều khoản để tiếp tục',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildConsentSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final service = _selectedService;
    final beneficiary = _selectedBeneficiary;
    final caregiver = _selectedCaregiver;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xác nhận đặt lịch',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Kiểm tra lại thông tin trước khi đặt',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        _buildConfirmCard('Dịch vụ', [
          if (service != null) _buildConfirmRow(service.icon, service.name),
        ]),
        const SizedBox(height: 10),
        _buildConfirmCard('Người được chăm sóc', [
          if (beneficiary != null)
            _buildConfirmRow(
                '👤', '${beneficiary.name} (${beneficiary.age} tuổi)'),
        ]),
        const SizedBox(height: 10),
        _buildConfirmCard('Người chăm sóc', [
          if (caregiver != null)
            _buildConfirmRow(
              '👩',
              '${caregiver.displayName}${_isSystemMatched ? ' • Hệ thống gợi ý' : ''}',
            )
          else if (_isSystemMatched)
            _buildConfirmRow(
              '🤖',
              'Hệ thống sẽ tự ghép chăm sóc viên phù hợp nhất',
            ),
        ]),
        const SizedBox(height: 10),
        _buildConfirmCard('Thời gian', [
          if (_selectedDate != null)
            _buildConfirmRow('📅',
                '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
          if (_startTime != null)
            _buildConfirmRow(
                '⏰', '${_startTime!.format(context)} • $_duration giờ'),
          if (_selectedAddressId != null)
            _buildConfirmRow(
              '📍',
              ref
                      .watch(addressStoreProvider)
                      .valueOrNull
                      ?.firstWhere(
                        (a) => a.id == _selectedAddressId,
                        orElse: () => AddressModel(
                            id: _selectedAddressId!,
                            fullAddress: _selectedAddressId!),
                      )
                      .shortAddress ??
                  '',
            ),
        ]),
        const SizedBox(height: 16),
        const Text(
          'Hình thức xác nhận',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildBookingModeTile(
          value: 'demo',
          icon: Icons.science_outlined,
          title: 'Xác nhận booking demo',
          subtitle: 'Không phát sinh thanh toán trong prototype',
        ),
        const SizedBox(height: 8),
        _buildBookingModeTile(
          value: 'mock_payment',
          icon: Icons.account_balance_wallet_outlined,
          title: 'Ví demo • giữ tiền mô phỏng',
          subtitle: 'Mô phỏng bước thanh toán trước khi caregiver nhận ca',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Tổng giá trị booking',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  service != null
                      ? '${(service.pricePerHour * _duration).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}đ'
                      : '---',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingModeTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _bookingMode == value;
    return InkWell(
      onTap: () => setState(() => _bookingMode = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primaryContainer : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLastStep = _currentStep == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            IconButton(
              onPressed: () => setState(() {
                // Nếu đang ở bước 2 và người thân đã chọn sẵn → quay về bước 0 (bỏ qua bước 1)
                if (_currentStep == 2 && widget.initialBeneficiaryId != null) {
                  _currentStep = 0;
                } else {
                  _currentStep--;
                }
              }),
              tooltip: 'Quay lại bước trước',
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _canContinue && !_isSubmitting
                  ? () {
                      if (isLastStep) {
                        _submitBooking();
                      } else {
                        setState(() {
                          // Khi isSystemMatched=true: giữ caregiverId=null
                          // Backend sẽ tự chọn caregiver phù hợp nhất.
                          // Không force-set caregiverId ở đây.
                          // Nếu đang ở bước 0 và người thân đã được chọn sẵn từ ngoài
                          // → bỏ qua bước 1, nhảy thẳng sang bước 2
                          if (_currentStep == 0 &&
                              widget.initialBeneficiaryId != null) {
                            _currentStep = 2;
                          } else {
                            _currentStep++;
                          }
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: isLastStep && _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(isLastStep ? 'Xác nhận đặt lịch' : 'Tiếp theo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting) return; // chặn double-submit
    final service = _selectedService;
    final beneficiary = _selectedBeneficiary;
    final caregiver = _selectedCaregiver;

    // Guard: tat ca fields bat buoc phai co
    if (service == null ||
        beneficiary == null ||
        _selectedDate == null ||
        _startTime == null ||
        _selectedAddressId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng điền đầy đủ thông tin trước khi xác nhận.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final end = start.add(Duration(hours: _duration));

    try {
      final booking =
          await ref.read(bookingStoreProvider.notifier).createBooking(
                BookingDraft(
                  beneficiaryId: beneficiary.id,
                  serviceTypeId: service.id,
                  caregiverId: caregiver?.id,
                  isSystemMatched: _isSystemMatched,
                  addressId: _selectedAddressId!,
                  scheduledStart: start,
                  scheduledEnd: end,
                ),
              );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo booking • đang chờ caregiver nhận ca'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pushReplacement('/bookings/${booking.id}');
      }
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is AppApiException) {
        _showSubmitApiError(apiError);
      } else {
        _showGenericSubmitError();
      }
    } on AppApiException catch (e) {
      _showSubmitApiError(e);
    } catch (e) {
      _showGenericSubmitError();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSubmitApiError(AppApiException e) {
    if (!mounted) return;

    final isCaregiverConflict = e.statusCode == 409;
    final msg = isCaregiverConflict
        ? 'Chăm sóc viên đã có lịch trong khung giờ này. Vui lòng chọn chăm sóc viên khác hoặc đổi giờ.'
        : e.message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        action: isCaregiverConflict
            ? SnackBarAction(
                label: 'Chọn lại',
                textColor: Colors.white,
                onPressed: () => setState(() {
                  _selectedCaregiverId = null;
                  _currentStep = 3; // về step Caregiver
                }),
              )
            : null,
      ),
    );
  }

  void _showGenericSubmitError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lỗi tạo booking. Vui lòng thử lại sau.'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
