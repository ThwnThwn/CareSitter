import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/navigation_helpers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/mock/mock_data.dart';
import '../../application/booking_store.dart';
import '../../../beneficiary/application/beneficiary_store.dart';

class BookingWizardScreen extends ConsumerStatefulWidget {
  final String? initialServiceId;

  const BookingWizardScreen({super.key, this.initialServiceId});

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
  String _bookingMode = 'demo';
  final TextEditingController _addressController = TextEditingController();

  bool get _hasUnsavedChanges =>
      _selectedServiceId != widget.initialServiceId ||
      _selectedBeneficiaryId != null ||
      _selectedCaregiverId != null ||
      _selectedDate != null ||
      _startTime != null ||
      _addressController.text.trim().isNotEmpty ||
      _duration != 4 ||
      _consentAccepted ||
      !_isSystemMatched ||
      _bookingMode != 'demo';

  static const _savedAddresses = [
    '123 Lê Văn Sỹ, Phường 13, Quận 3, TP.HCM',
    '456 Nguyễn Trọng Tuyển, Phường 15, Quận Phú Nhuận, TP.HCM',
    '78 Điện Biên Phủ, Quận Bình Thạnh, TP.HCM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.initialServiceId;
    if (_selectedServiceId != null) _currentStep = 1;
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  final List<String> _stepTitles = [
    'Dịch vụ',
    'Người thân',
    'Lịch & địa chỉ',
    'Caregiver',
    'Đồng ý',
    'Xác nhận'
  ];

  MockService? get _selectedService => _selectedServiceId != null
      ? MockData.services.firstWhere((s) => s.id == _selectedServiceId,
          orElse: () => MockData.services.first)
      : null;

  MockBeneficiary? get _selectedBeneficiary {
    if (_selectedBeneficiaryId == null) return null;
    final all = ref.read(beneficiaryStoreProvider);
    return all.firstWhere(
      (b) => b.id == _selectedBeneficiaryId,
      orElse: () => all.first,
    );
  }

  MockCaregiver? get _selectedCaregiver => _selectedCaregiverId != null
      ? MockData.caregivers.firstWhere((c) => c.id == _selectedCaregiverId,
          orElse: () => MockData.caregivers.first)
      : null;

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

  List<MockCaregiver> get _matchedCaregivers {
    final candidates = MockData.caregivers.where((c) => c.isAvailable).toList();
    candidates.sort((a, b) => _matchScore(b).compareTo(_matchScore(a)));
    final serviceMatches = candidates.where((c) => _matchesService(c)).toList();
    return serviceMatches.isEmpty ? candidates : serviceMatches;
  }

  bool _matchesService(MockCaregiver caregiver) {
    final skills = caregiver.skills.join(' ').toLowerCase();
    final keywords = switch (_selectedServiceId) {
      'sv001' => const ['đồng hành', 'cao tuổi', 'người già', 'lớn tuổi'],
      'sv002' => const ['ban đêm', 'cao tuổi', 'người già'],
      'sv003' || 'sv007' || 'sv008' => const ['trẻ', 'mầm non', 'montessori'],
      'sv004' => const ['dọn dẹp', 'giúp việc'],
      'sv005' => const ['nấu ăn'],
      'sv006' => const ['đưa đón', 'lái xe'],
      _ => const <String>[],
    };
    return keywords.isEmpty || keywords.any(skills.contains);
  }

  int _matchScore(MockCaregiver caregiver) {
    var score = _matchesService(caregiver) ? 100 : 0;
    final normalizedAddress =
        _addressController.text.toLowerCase().replaceAll('quận', 'q.');
    final district = caregiver.location
        .split(',')
        .first
        .toLowerCase()
        .replaceAll('quận', 'q.');
    if (normalizedAddress.contains(district)) score += 30;
    score += (caregiver.rating * 10).round();
    return score;
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedServiceId != null;
      case 1:
        return _selectedBeneficiaryId != null;
      case 2:
        return _hasValidSchedule && _addressController.text.trim().isNotEmpty;
      case 3:
        return _selectedCaregiverId != null;
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
                child: _buildCurrentStep(),
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
    return Column(
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
        ...MockData.services.map((s) {
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
                        child:
                            Text(s.icon, style: const TextStyle(fontSize: 22))),
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
        const SizedBox(height: 16),
        ...beneficiaries.map((b) {
          final isSelected = _selectedBeneficiaryId == b.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedBeneficiaryId = b.id),
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
          '${available.length} caregiver phù hợp với dịch vụ, lịch và khu vực',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (available.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() {
              _isSystemMatched = true;
              _selectedCaregiverId = available.first.id;
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
                  color:
                      _isSystemMatched ? AppColors.primary : AppColors.border,
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
                          '${available.first.name} • điểm phù hợp cao nhất',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_isSystemMatched)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const Text(
            'Hoặc tự chọn caregiver',
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(c.avatarInitial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (c.isAvailable)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
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
                                child: Text(c.name,
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
                            Text('${c.rating} • ${c.experience}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                        Text('${c.hourlyRate.toInt()}đ/giờ',
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
  }

  Widget _buildTimeStep() {
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
        // Date picker placeholder
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
        const Text('Thời lượng (giờ)',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [2, 4, 6, 8, 12].map((h) {
            final isSelected = _duration == h;
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
                      color: isSelected ? AppColors.primary : AppColors.border),
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
        const Text('Địa chỉ chăm sóc',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _savedAddresses.asMap().entries.map((entry) {
            final selected = _addressController.text == entry.value;
            return ChoiceChip(
              label: Text(entry.key == 0
                  ? 'Nhà riêng'
                  : entry.key == 1
                      ? 'Nhà bố mẹ'
                      : 'Văn phòng'),
              selected: selected,
              onSelected: (_) => setState(() {
                _addressController.text = entry.value;
                _selectedCaregiverId = null;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          maxLines: 2,
          onChanged: (_) => setState(() => _selectedCaregiverId = null),
          decoration: const InputDecoration(
            labelText: 'Địa chỉ chi tiết *',
            hintText: 'Số nhà, đường, phường/xã, quận/huyện',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
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
              '${caregiver.name}${_isSystemMatched ? ' • Hệ thống gợi ý' : ''}',
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
          _buildConfirmRow('📍', _addressController.text.trim()),
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
              const Text('Tổng giá trị booking',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text(
                service != null
                    ? '${(service.pricePerHour * _duration).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}đ'
                    : '---',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
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
              onPressed: () => setState(() => _currentStep--),
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
              onPressed: _canContinue
                  ? () {
                      if (isLastStep) {
                        _submitBooking();
                      } else {
                        setState(() {
                          if (_currentStep == 2 &&
                              _selectedCaregiverId == null &&
                              _matchedCaregivers.isNotEmpty) {
                            _selectedCaregiverId = _matchedCaregivers.first.id;
                            _isSystemMatched = true;
                          }
                          _currentStep++;
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: Text(isLastStep ? 'Xác nhận đặt lịch' : 'Tiếp theo'),
            ),
          ),
        ],
      ),
    );
  }

  void _submitBooking() {
    final service = _selectedService;
    final beneficiary = _selectedBeneficiary;
    final caregiver = _selectedCaregiver;
    if (service == null ||
        beneficiary == null ||
        caregiver == null ||
        _selectedDate == null ||
        _startTime == null) {
      return;
    }

    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = startMinutes + _duration * 60;
    final startLabel =
        '${twoDigits(_startTime!.hour)}:${twoDigits(_startTime!.minute)}';
    final endLabel =
        '${twoDigits((endMinutes ~/ 60) % 24)}:${twoDigits(endMinutes % 60)}';

    final booking = ref.read(bookingStoreProvider.notifier).createBooking(
          BookingDraft(
            beneficiaryId: beneficiary.id,
            beneficiaryName: beneficiary.name,
            caregiverId: caregiver.id,
            caregiverName: caregiver.name,
            caregiverAvatar: caregiver.avatarInitial,
            serviceId: service.id,
            serviceName: service.name,
            date:
                '${twoDigits(_selectedDate!.day)}/${twoDigits(_selectedDate!.month)}/${_selectedDate!.year}',
            time: '$startLabel — $endLabel',
            duration: '$_duration giờ',
            totalPrice: service.pricePerHour * _duration,
            address: _addressController.text.trim(),
            isSystemMatched: _isSystemMatched,
            isDemoBooking: _bookingMode == 'demo',
            paymentLabel: _bookingMode == 'demo'
                ? 'Booking demo • không thanh toán'
                : 'Ví demo • đã giữ tiền mô phỏng',
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã tạo booking • đang chờ caregiver nhận ca'),
        backgroundColor: AppColors.success,
      ),
    );
    context.pushReplacement('/bookings/${booking.id}');
  }
}
