import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import '../controllers/self_recipient_controller.dart';
import '../widgets/self_recipient_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:dio/dio.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/core/api/dio_client.dart'
    show AppApiException;
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

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
  bool _forSelf = false;
  bool _selfDateValid = true;
  bool _initialResolved = false;
  bool _bookingUncertain = false;
  int _sessionVersion = 0;
  BookingDraft? _uncertainDraft;
  String _submitLabel = 'Đang đặt lịch…';
  ProviderSubscription<AsyncValue<List<BeneficiaryModel>>>?
      _recipientSubscription;
  ProviderSubscription<AsyncValue<dynamic>>? _sessionSubscription;
  String? _selectedServiceId;
  String? _selectedBeneficiaryId;
  String? _selectedCaregiverId;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  int _duration = 2; // hours
  bool _consentAccepted = false; // FR-CUS-09
  bool _isSystemMatched = true;
  bool _isSubmitting = false; // guard chống double-submit
  String? _selectedAddressId; // ID địa chỉ thật từ API

  bool get _hasUnsavedChanges =>
      _forSelf ||
      _selectedServiceId != widget.initialServiceId ||
      _selectedBeneficiaryId != widget.initialBeneficiaryId ||
      _selectedCaregiverId != null ||
      _selectedDate != null ||
      _startTime != null ||
      _selectedAddressId != null ||
      _duration != 2 ||
      _consentAccepted ||
      !_isSystemMatched;

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.initialServiceId;
    _selectedBeneficiaryId = widget.initialBeneficiaryId;

    _currentStep = _selectedServiceId == null ? 0 : 1;
    _recipientSubscription =
        ref.listenManual(bookingRecipientsProvider, (_, next) {
      if (_initialResolved || widget.initialBeneficiaryId == null || !mounted) {
        return;
      }
      final records = next.valueOrNull;
      if (records == null) return;
      _initialResolved = true;
      final version = _sessionVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || version != _sessionVersion) return;
        final matches =
            records.where((b) => b.id == widget.initialBeneficiaryId);
        if (matches.isEmpty) {
          setState(() => _selectedBeneficiaryId = null);
          return;
        }
        final profile = matches.single;
        if (profile.isSelf) {
          ref.read(selfRecipientProvider.notifier).acceptExisting(profile);
        }
        setState(() {
          _forSelf = profile.isSelf;
          _selectedAddressId = profile.defaultAddressId;
        });
      });
    }, fireImmediately: true);
    _sessionSubscription =
        ref.listenManual(authStateProvider, (previous, next) {
      if (previous?.value?.userId == next.value?.userId || !mounted) return;
      _sessionVersion++;
      setState(() {
        _forSelf = false;
        _selectedBeneficiaryId = null;
        _selectedAddressId = null;
        _selectedCaregiverId = null;
        _selectedServiceId = null;
        _selectedDate = null;
        _startTime = null;
        _consentAccepted = false;
        _bookingUncertain = false;
        _uncertainDraft = null;
        _currentStep = 0;
        _initialResolved = true;
      });
    });
  }

  @override
  void dispose() {
    _recipientSubscription?.close();
    _sessionSubscription?.close();
    super.dispose();
  }

  final List<String> _stepTitles = [
    'Dịch vụ',
    'Người nhận',
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
    return list.where((s) => s.id == _selectedServiceId).firstOrNull;
  }

  BeneficiaryModel? get _selectedBeneficiary {
    if (_forSelf) return ref.read(selfRecipientProvider).valueOrNull?.profile;
    return ref
        .read(bookingRecipientsProvider)
        .valueOrNull
        ?.where((b) => b.id == _selectedBeneficiaryId && !b.isSelf)
        .firstOrNull;
  }

  bool get _recipientReady => _forSelf
      ? _selfDateValid &&
          (ref.read(selfRecipientProvider).valueOrNull?.isComplete ?? false)
      : _selectedBeneficiary != null;

  CaregiverModel? get _selectedCaregiver {
    if (_selectedCaregiverId == null) return null;
    final caregiverAsync = ref.read(caregiverStoreProvider);
    final list = caregiverAsync.valueOrNull ?? [];
    if (list.isEmpty) return null;
    return list.where((c) => c.id == _selectedCaregiverId).firstOrNull;
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

  /// Booking chỉ nhận mốc 5 phút để tránh các giờ khó đọc như 10:13.
  /// Nếu làm tròn qua 00:00, ngày đã chọn cũng phải tiến thêm một ngày.
  ({TimeOfDay time, bool movesToNextDay}) _snapToFiveMinutes(TimeOfDay time) {
    final minutesSinceMidnight = time.hour * 60 + time.minute;
    final roundedMinutes = ((minutesSinceMidnight + 2) ~/ 5) * 5;

    return (
      time: TimeOfDay(
        hour: (roundedMinutes ~/ 60) % 24,
        minute: roundedMinutes % 60,
      ),
      movesToNextDay: roundedMinutes >= 24 * 60,
    );
  }

  bool get _selectedAddressIsVerified {
    if (_selectedAddressId == null) return false;
    final addresses = ref.read(addressStoreProvider).valueOrNull ?? [];
    return addresses.any((a) => a.id == _selectedAddressId && a.isVerified);
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
        return _selectedService != null;
      case 1:
        return _recipientReady;
      case 2:
        return _hasValidSchedule && _selectedAddressIsVerified;
      case 3:
        return _selectedCaregiverId != null || _isSystemMatched;
      case 4:
        return _consentAccepted;
      default:
        return _recipientReady &&
            _hasValidSchedule &&
            _selectedAddressIsVerified &&
            _consentAccepted;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bookingRecipientsProvider);
    ref.watch(selfRecipientProvider);
    ref.watch(serviceStoreProvider);
    ref.watch(addressStoreProvider);
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
          shadowColor: AppColors.shadow,
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
                child: AbsorbPointer(
                    absorbing: _isSubmitting || _bookingUncertain,
                    child: FadeSlideStaggered(
                      key: ValueKey(_currentStep),
                      index: 0,
                      child: _buildCurrentStep(),
                    )),
              ),
            ),
            if (_bookingUncertain) _buildUncertainBooking(),
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
    final records = ref.watch(bookingRecipientsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bạn đặt dịch vụ cho ai?',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true,
                label: Text('Tôi'),
                icon: Icon(Icons.person_outline)),
            ButtonSegment(
                value: false,
                label: Text('Người thân'),
                icon: Icon(Icons.people_outline)),
          ],
          selected: {
            _forSelf
          },
          onSelectionChanged: (value) => setState(() {
                _forSelf = value.single;
                _selectedAddressId = _selectedBeneficiary?.defaultAddressId;
              })),
      const SizedBox(height: 20),
      if (_forSelf)
        _buildSelfRecipient()
      else
        records.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _recipientError(
                () => ref.invalidate(bookingRecipientsProvider)),
            data: (items) => Column(children: [
                  if (items.where((b) => !b.isSelf).isEmpty)
                    const Text(
                        'Chưa có hồ sơ người thân. Bạn có thể thêm ngay tại đây.'),
                  for (final b in items.where((b) => !b.isSelf))
                    RadioGroup<String>(
                        groupValue: _selectedBeneficiaryId,
                        onChanged: (id) => setState(() {
                              _selectedBeneficiaryId = id;
                              _selectedAddressId = b.defaultAddressId;
                            }),
                        child: RadioListTile<String>(
                          value: b.id,
                          title: Text(b.name),
                          subtitle: Text('${b.ageLabel} • ${b.relation}'),
                        )),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Thêm người thân mới'),
                      onPressed: () async {
                        final userId =
                            ref.read(authStateProvider).value?.userId;
                        final id =
                            await context.push<String>('/beneficiaries/create');
                        if (!mounted ||
                            ref.read(authStateProvider).value?.userId !=
                                userId ||
                            id == null) {
                          return;
                        }
                        ref.invalidate(bookingRecipientsProvider);
                        try {
                          final items =
                              await ref.read(bookingRecipientsProvider.future);
                          if (!mounted ||
                              ref.read(authStateProvider).value?.userId !=
                                  userId) {
                            return;
                          }
                          final profile = items
                              .where((b) => b.id == id && !b.isSelf)
                              .firstOrNull;
                          if (profile != null) {
                            setState(() {
                              _selectedBeneficiaryId = profile.id;
                              _selectedAddressId = profile.defaultAddressId;
                            });
                          }
                        } catch (_) {
                          /* Provider hiển thị lỗi tải và thao tác thử lại. */
                        }
                      }),
                ])),
    ]);
  }

  Widget _recipientError(VoidCallback retry) => Column(children: [
        const Text('Không tải được thông tin. Vui lòng thử lại.'),
        TextButton(onPressed: retry, child: const Text('Thử lại')),
      ]);

  Widget _buildSelfRecipient() => ref.watch(selfRecipientProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _recipientError(
          () => ref.read(selfRecipientProvider.notifier).load()),
      data: (selected) {
        final profile = selected.profile;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (selected.kind != SelfRecipientKind.draft) ...[
            Text('Tôi — ${profile.name}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('${profile.ageLabel} • ${profile.careLevelLabel}'),
            if (profile.condition.isNotEmpty) Text(profile.condition),
            if (profile.notes.isNotEmpty) Text(profile.notes),
            for (final contact in profile.emergencyContacts)
              Text('${contact.name}: ${contact.phone}'),
            if (!selected.isComplete)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'Vui lòng bổ sung họ tên và hai liên hệ khẩn cấp trước khi tiếp tục.')),
            TextButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Sửa thông tin chăm sóc'),
                onPressed: () async {
                  ref
                      .read(beneficiaryStoreProvider.notifier)
                      .acceptSaved(profile);
                  final userId = ref.read(authStateProvider).value?.userId;
                  await context.push('/beneficiaries/${profile.id}/edit');
                  if (!mounted ||
                      ref.read(authStateProvider).value?.userId != userId) {
                    return;
                  }
                  ref.invalidate(bookingRecipientsProvider);
                  if (selected.kind == SelfRecipientKind.existing) {
                    await ref.read(selfRecipientProvider.notifier).load();
                  } else {
                    try {
                      final updated = await ref
                          .read(beneficiaryRepositoryProvider)
                          .getBeneficiary(profile.id);
                      if (!mounted ||
                          ref.read(authStateProvider).value?.userId != userId) {
                        return;
                      }
                      ref
                          .read(selfRecipientProvider.notifier)
                          .selectLink(updated);
                    } catch (_) {
                      if (mounted) {
                        ref.read(selfRecipientProvider.notifier).load();
                      }
                    }
                  }
                }),
            if (selected.kind == SelfRecipientKind.link)
              TextButton(
                  onPressed: () =>
                      ref.read(selfRecipientProvider.notifier).useDraft(),
                  child: const Text('Dùng thông tin tài khoản')),
          ] else ...[
            SelfRecipientForm(
                initial: profile,
                onDateValidityChanged: (valid) {
                  if (_selfDateValid != valid) {
                    setState(() => _selfDateValid = valid);
                  }
                },
                onChanged: (value) => ref
                    .read(selfRecipientProvider.notifier)
                    .updateDraft(value)),
            const SizedBox(height: 16),
            ExpansionTile(
                title: const Text('Dùng hồ sơ đã có của tôi'),
                children: [
                  ref.watch(bookingRecipientsProvider).when(
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => _recipientError(
                          () => ref.invalidate(bookingRecipientsProvider)),
                      data: (items) => Column(children: [
                            if (items.where((b) => !b.isSelf).isEmpty)
                              const ListTile(
                                  title: Text('Chưa có hồ sơ để chọn.')),
                            for (final item in items.where((b) => !b.isSelf))
                              ListTile(
                                  title: Text(item.name),
                                  subtitle: Text(
                                      '${item.ageLabel} • ${item.relation}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    ref
                                        .read(selfRecipientProvider.notifier)
                                        .selectLink(item);
                                    setState(() {
                                      _selfDateValid = true;
                                      _selectedAddressId =
                                          item.defaultAddressId;
                                    });
                                  }),
                          ]))
                ]),
          ],
        ]);
      });

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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Để hệ thống gợi ý',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              'Hệ thống sẽ chọn người phù hợp nhất cho bạn',
                              style: TextStyle(
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
                                    size: 12, color: AppColors.secondary),
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
        const SizedBox(height: 20),

        // ── Ngày ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.cardBackground,
                  ),
                ),
                child: child!,
              ),
            );
            if (mounted && picked != null) {
              setState(() {
                _selectedDate = picked;
                _startTime = null;
                _selectedCaregiverId = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedDate != null
                    ? AppColors.primary
                    : AppColors.border,
                width: _selectedDate != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: _selectedDate != null
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'Chọn ngày'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _selectedDate != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _selectedDate != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Giờ bắt đầu ───────────────────────────────────────────────────
        GestureDetector(
          onTap: _selectedDate == null
              ? null
              : () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _snapToFiveMinutes(
                      _startTime ?? const TimeOfDay(hour: 8, minute: 0),
                    ).time,
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          surface: AppColors.cardBackground,
                          onSurface: AppColors.textPrimary,
                        ),
                        timePickerTheme: TimePickerThemeData(
                          dialBackgroundColor: AppColors.divider,
                          dialHandColor: AppColors.primary,
                          dialTextColor: WidgetStateColor.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          hourMinuteColor: WidgetStateColor.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.primaryContainer
                                : AppColors.divider,
                          ),
                          hourMinuteTextColor: WidgetStateColor.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                          ),
                          dayPeriodColor: WidgetStateColor.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.primaryContainer
                                : Colors.white,
                          ),
                          dayPeriodTextColor: WidgetStateColor.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                          ),
                          dayPeriodBorderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                          entryModeIconColor: AppColors.primary,
                          helpTextStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (mounted && picked != null) {
                    final snapped = _snapToFiveMinutes(picked);
                    setState(() {
                      _startTime = snapped.time;
                      if (snapped.movesToNextDay) {
                        _selectedDate =
                            _selectedDate!.add(const Duration(days: 1));
                      }
                      _selectedCaregiverId = null;
                    });
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _selectedDate == null
                  ? AppColors.surfaceVariant.withValues(alpha: 0.5)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _startTime != null ? AppColors.primary : AppColors.border,
                width: _startTime != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: _startTime != null
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _startTime == null
                        ? (_selectedDate == null
                            ? 'Chọn ngày trước'
                            : 'Chọn giờ bắt đầu')
                        : _startTime!.format(context),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _startTime != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _startTime != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textHint),
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
        const SizedBox(height: 24),

        // ── Thời lượng ca chăm sóc (Theo thiết kế Stitch) ─────────────────
        Builder(
          builder: (context) {
            final rate = _selectedService?.pricePerHour ?? 110000;
            final isCustom = _duration != 2 &&
                _duration != 4 &&
                _duration != 8 &&
                _duration != 12;
            final totalDurationPrice = (rate * _duration).toInt();
            final totalFormatted =
                '${totalDurationPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
            final rateFormatted =
                '${rate.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ/h';

            String helperText;
            switch (_duration) {
              case 2:
                helperText = 'Ca ngắn / Hỗ trợ nhanh';
                break;
              case 3:
                helperText = 'Hỗ trợ buổi sáng/chiều';
                break;
              case 4:
                helperText = 'Nửa ngày tiêu chuẩn';
                break;
              case 5:
                helperText = 'Phù hợp nửa ngày + ăn trưa';
                break;
              case 6:
                helperText = 'Hơn nửa ngày làm việc';
                break;
              case 7:
                helperText = 'Ca gần trọn ngày';
                break;
              case 8:
                helperText = 'Trọn 1 ca hành chính';
                break;
              case 12:
                helperText = 'Ca trọn ngày 12 giờ';
                break;
              default:
                helperText = 'Linh hoạt theo nhu cầu';
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thời lượng ca chăm sóc',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('Linh hoạt theo giờ',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                  const SizedBox(height: 14),

                  // 2. 4 Gói presets (2h, 4h, 8h, 12h)
                  Row(
                    children: [
                      _buildDurationPresetItem(
                        label: '2h',
                        hours: 2,
                        isSelected: _duration == 2,
                      ),
                      const SizedBox(width: 8),
                      _buildDurationPresetItem(
                        label: '4h',
                        hours: 4,
                        isSelected: _duration == 4,
                      ),
                      const SizedBox(width: 8),
                      _buildDurationPresetItem(
                        label: '8h',
                        hours: 8,
                        isSelected: _duration == 8,
                      ),
                      const SizedBox(width: 8),
                      _buildDurationPresetItem(
                        label: '12h',
                        hours: 12,
                        isSelected: _duration == 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Card Tùy chỉnh số giờ
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCustom
                          ? AppColors.primaryContainer.withValues(alpha: 0.35)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCustom ? AppColors.primary : AppColors.border,
                        width: isCustom ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng tiêu đề tùy chỉnh + Tổng tiền
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isCustom
                                        ? AppColors.primary
                                        : AppColors.border,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCustom
                                      ? 'Tùy chỉnh số giờ (Đang chọn)'
                                      : 'Tùy chỉnh số giờ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCustom
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              totalFormatted,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Khung tăng giảm stepper + Đơn giá / gợi ý
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Nút Giảm [-]
                              InkWell(
                                onTap: _duration > 2
                                    ? () => setState(() => _duration--)
                                    : null,
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _duration > 2
                                        ? AppColors.divider
                                        : AppColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    size: 18,
                                    color: _duration > 2
                                        ? AppColors.textPrimary
                                        : AppColors.textHint,
                                  ),
                                ),
                              ),

                              // Số giờ
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_duration',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Giờ chăm sóc',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Nút Tăng [+]
                              InkWell(
                                onTap: _duration < 12
                                    ? () => setState(() => _duration++)
                                    : null,
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _duration < 12
                                        ? AppColors.primaryContainer
                                        : AppColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: _duration < 12
                                        ? AppColors.primaryDark
                                        : AppColors.textHint,
                                  ),
                                ),
                              ),

                              // Đường kẻ phân cách dọc
                              Container(
                                width: 1,
                                height: 38,
                                color: AppColors.border,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),

                              // Thông tin đơn giá & gợi ý bên phải
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      rateFormatted,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      helperText,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Ghi chú dưới cùng
                        const Text(
                          'Linh hoạt từ 2 – 12 giờ theo nhu cầu gia đình. Có thể thỏa thuận thêm thời gian phát sinh.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Địa chỉ chăm sóc ────────────────────────────────────────────
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
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
        if (_selectedAddressId != null && !_selectedAddressIsVerified) ...[
          const SizedBox(height: 8),
          const Text(
            'Địa chỉ này chưa được xác minh. Vui lòng thêm/chọn địa chỉ từ danh sách gợi ý.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ],
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

  Widget _buildDurationPresetItem({
    required String label,
    required int hours,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _duration = hours),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.5)
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color:
                    isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
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
          color: address.isVerified
              ? AppColors.primaryContainer
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: address.isVerified ? AppColors.primary : AppColors.warning,
            width: 2,
          ),
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
    final consentHeight = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(220.0, 320.0)
        .toDouble();

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
          height: consentHeight,
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
              Expanded(
                  child: Text(
                'Bạn cần đồng ý với điều khoản để tiếp tục',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              )),
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
            _buildConfirmRow('👤',
                '${_forSelf ? 'Tôi — ' : ''}${beneficiary.name} (${beneficiary.ageLabel})'),
          if (beneficiary != null && _forSelf) ...[
            Text(beneficiary.careLevelLabel),
            if (beneficiary.condition.isNotEmpty) Text(beneficiary.condition),
            if (beneficiary.notes.isNotEmpty) Text(beneficiary.notes),
            for (final c in beneficiary.emergencyContacts)
              Text('${c.name}: ${c.phone}'),
          ],
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
              onPressed: _isSubmitting || _bookingUncertain
                  ? null
                  : () => setState(() => _currentStep--),
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
              onPressed: _canContinue && !_isSubmitting && !_bookingUncertain
                  ? () {
                      if (isLastStep) {
                        _submitBooking();
                      } else {
                        setState(() {
                          if (_currentStep == 1 && _selectedAddressId == null) {
                            _selectedAddressId =
                                _selectedBeneficiary?.defaultAddressId;
                          }
                          _currentStep++;
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: isLastStep && _isSubmitting
                  ? Text(_submitLabel, textAlign: TextAlign.center)
                  : Text(isLastStep ? 'Xác nhận đặt lịch' : 'Tiếp theo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting || _bookingUncertain) return;
    final sessionVersion = _sessionVersion;
    final userId = ref.read(authStateProvider).value?.userId;
    bool currentSession() =>
        mounted &&
        _sessionVersion == sessionVersion &&
        ref.read(authStateProvider).value?.userId == userId;
    final service = _selectedService;
    var beneficiary = _selectedBeneficiary;
    final caregiver = _selectedCaregiver;

    // Guard: tat ca fields bat buoc phai co
    if (userId == null ||
        !_recipientReady ||
        !_hasValidSchedule ||
        !_selectedAddressIsVerified ||
        !_consentAccepted ||
        (!_isSystemMatched && caregiver == null) ||
        service == null ||
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
      if (_forSelf) {
        setState(() => _submitLabel = 'Đang lưu thông tin chăm sóc…');
        final resolved = await ref
            .read(selfRecipientProvider.notifier)
            .resolve(_selectedAddressId!);
        if (!mounted || !currentSession()) return;
        beneficiary = resolved.profile;
        ref.invalidate(bookingRecipientsProvider);
        ref.read(beneficiaryStoreProvider.notifier).acceptSaved(beneficiary);
        if (resolved.needsReview ||
            !ref.read(selfRecipientProvider).requireValue.isComplete) {
          setState(() => _currentStep = 1);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Hồ sơ đã được cập nhật. Vui lòng kiểm tra lại trước khi đặt lịch.')));
          return;
        }
      }
      if (!mounted || !currentSession()) return;
      setState(() => _submitLabel = 'Đang đặt lịch…');
      final draft = BookingDraft(
          beneficiaryId: beneficiary.id,
          serviceTypeId: service.id,
          caregiverId: caregiver?.id,
          isSystemMatched: _isSystemMatched,
          addressId: _selectedAddressId!,
          scheduledStart: start,
          scheduledEnd: end);
      _uncertainDraft = draft;
      final booking =
          await ref.read(bookingStoreProvider.notifier).createBooking(draft);
      if (!mounted || !currentSession()) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã tạo booking • đang chờ caregiver nhận ca'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pushReplacement('/bookings/${booking.id}');
      }
    } on BookingCreatedException catch (e) {
      if (!mounted || !currentSession()) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Lịch đã được tạo. Chưa xác nhận được người chăm sóc; hãy kiểm tra trên lịch này.')));
      context.pushReplacement('/bookings/${e.booking.id}');
    } on BookingOutcomeUnknown {
      if (currentSession()) setState(() => _bookingUncertain = true);
    } on DioException catch (e) {
      if (!mounted || !currentSession()) return;
      final apiError = e.error;
      if (apiError is AppApiException) {
        _showSubmitApiError(apiError);
      } else {
        _showGenericSubmitError();
      }
    } on AppApiException catch (e) {
      if (!mounted || !currentSession()) return;
      _showSubmitApiError(e);
    } catch (e) {
      if (currentSession()) _showGenericSubmitError();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSubmitApiError(AppApiException e) {
    if (!mounted) return;

    final isCaregiverConflict = const {
      'booking.caregiver.schedule_conflict',
      'booking.caregiver.new_schedule_conflict',
    }.contains(e.code);
    if (e.code?.startsWith('beneficiary.') ?? false) {
      setState(() => _currentStep = 1);
      if (e.code == 'beneficiary.self_exists') {
        ref.read(selfRecipientProvider.notifier).load();
      }
    }
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

  Widget _buildUncertainBooking() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text(
            'Chưa xác định được lịch đã tạo hay chưa. Kiểm tra lịch đã gửi trước khi đặt tiếp.'),
        TextButton(
            onPressed: _isSubmitting ? null : _checkUncertainBooking,
            child: const Text('Kiểm tra lịch đã gửi')),
        TextButton(
            onPressed: () => context.go('/bookings'),
            child: const Text('Xem danh sách lịch')),
      ]));

  Future<void> _checkUncertainBooking() async {
    final draft = _uncertainDraft;
    if (draft == null || _isSubmitting) return;
    final userId = ref.read(authStateProvider).value?.userId;
    setState(() => _isSubmitting = true);
    try {
      final result =
          await ref.read(bookingRepositoryProvider).getBookings(pageSize: 100);
      if (!mounted || ref.read(authStateProvider).value?.userId != userId) {
        return;
      }
      final matches = result.items
          .where((b) =>
              b.beneficiaryId == draft.beneficiaryId &&
              b.serviceTypeId == draft.serviceTypeId &&
              b.addressId == draft.addressId &&
              b.scheduledStart.isAtSameMomentAs(draft.scheduledStart) &&
              b.scheduledEnd.isAtSameMomentAs(draft.scheduledEnd))
          .toList();
      if (matches.length == 1) {
        context.pushReplacement('/bookings/${matches.single.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Chưa xác minh được kết quả. Vui lòng kiểm tra danh sách lịch hoặc liên hệ hỗ trợ.')));
      }
    } catch (_) {
      if (mounted && ref.read(authStateProvider).value?.userId == userId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa tải được lịch. Vui lòng kiểm tra lại.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showGenericSubmitError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Chưa hoàn tất đặt lịch. Vui lòng kiểm tra thông tin và thử lại.'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}