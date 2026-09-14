import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/router/navigation_helpers.dart';
import '../data/shift_model.dart';
import 'providers/shifts_provider.dart';

class ShiftActiveScreen extends ConsumerStatefulWidget {
  final String id;
  const ShiftActiveScreen({super.key, required this.id});

  @override
  ConsumerState<ShiftActiveScreen> createState() => _ShiftActiveScreenState();
}

class _ShiftActiveScreenState extends ConsumerState<ShiftActiveScreen>
    with TickerProviderStateMixin {
  // ── Check-in state ────────────────────────────────────────
  int _checkInStep = 0; // 0 = not started, 1 = selfie, 2 = gps, 3 = done
  bool _isCheckedIn = false;
  bool _isSubmittingCheckIn = false;
  DateTime? _checkInTime;
  bool _didRestoreServerState = false;
  bool _didRequestTasks = false;

  // ── Animated step transitions ─────────────────────────────
  late AnimationController _stepAnim;
  late Animation<double> _stepFade;

  // ── Live work timer ───────────────────────────────────────
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // ── Task photos ───────────────────────────────────────────
  final Map<String, List<String>> _taskPhotos = {};
  final ImagePicker _imagePicker = ImagePicker();

  // ── Per-task submit lock (prevent double-tap) ─────────────
  final Set<String> _submittingTaskIds = {};

  // ── Caregiver note ────────────────────────────────────────
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stepAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _stepFade = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut);
    _stepAnim.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepAnim.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startTimer([DateTime? startedAt]) {
    final now = DateTime.now();
    final candidate = (startedAt ?? now).toLocal();
    // A bad/future server timestamp must never render a negative duration.
    _checkInTime = candidate.isAfter(now) ? now : candidate;
    _elapsed = _durationSince(_checkInTime!, now);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = _durationSince(_checkInTime!, DateTime.now());
        });
      }
    });
  }

  Duration _durationSince(DateTime start, DateTime end) {
    final elapsed = end.difference(start);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void _restoreFromServerState(ShiftModel booking) {
    if (_didRestoreServerState) return;
    _didRestoreServerState = true;

    final wasCheckedIn = booking.status == 'in_progress' ||
        booking.status == 'checkout_pending_review' ||
        booking.status == 'completed';
    if (!wasCheckedIn) return;

    final startedAt = booking.actualStart ?? booking.scheduledStart;
    setState(() {
      _isCheckedIn = true;
      _checkInStep = 3;
      _checkInTime = startedAt != null && startedAt.isAfter(DateTime.now())
          ? DateTime.now()
          : startedAt;
      if (startedAt != null) {
        final end = booking.checkoutRequestedAt ?? DateTime.now();
        _elapsed = _durationSince(startedAt, end);
      }
    });

    if (booking.status == 'in_progress' && startedAt != null) {
      _startTimer(startedAt);
    }
  }

  Future<void> _loadTasks() async {
    if (_didRequestTasks) return;
    _didRequestTasks = true;
    try {
      await ref.read(shiftsProvider.notifier).loadTasks(widget.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải checklist công việc.')),
      );
    }
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _checkInTimeLabel {
    if (_checkInTime == null) return '';
    final t = _checkInTime!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  // ── Advance through check-in steps ───────────────────────
  Future<void> _advanceStep() async {
    _stepAnim.reset();
    setState(() => _checkInStep++);
    await _stepAnim.forward();

    if (_checkInStep == 3) {
      // Small delay then mark as done
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _isCheckedIn = true);
        _startTimer();
      }
    }
  }

  Future<void> _confirmGpsCheckIn(ShiftModel booking) async {
    setState(() => _isSubmittingCheckIn = true);
    try {
      await ref.read(shiftsProvider.notifier).checkIn(booking.id);
      if (!mounted) return;
      await _advanceStep();
    } catch (error) {
      if (!mounted) return;
      final message = _checkInErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingCheckIn = false);
    }
  }

  String _checkInErrorMessage(Object error) {
    if (error is LocationUnavailableException) return error.message;
    if (error is DioException && error.error is AppApiException) {
      return (error.error as AppApiException).message;
    }
    return 'Khong the lay vi tri GPS. Hay thu lai sau it phut.';
  }

  Future<void> _pickTaskPhoto(ShiftModel booking, CareTaskModel task) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text('Đính kèm minh chứng',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Chụp ảnh minh chứng'),
              subtitle: const Text('Mở camera để chụp ngay'),
              onTap: () async {
                Navigator.pop(ctx);
                await _uploadTaskPhoto(booking, task, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Chọn từ Thư viện'),
              subtitle: const Text('Tải ảnh đã có sẵn'),
              onTap: () async {
                Navigator.pop(ctx);
                await _uploadTaskPhoto(booking, task, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadTaskPhoto(
      ShiftModel booking, CareTaskModel task, ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final cropped = await _cropImage(picked);
    if (cropped == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang xử lý ảnh…'),
        duration: Duration(milliseconds: 600),
      ),
    );
    try {
      final raw = await ref
          .read(shiftsProvider.notifier)
          .uploadTaskPhoto(booking.id, task.id, cropped);
      final url = raw['url']?.toString();
      if (!mounted || url == null || url.isEmpty) return;
      setState(() => _taskPhotos[task.title] = [
            ...?_taskPhotos[task.title],
            url,
          ]);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Đã tải ảnh minh chứng cho: ${task.title}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Không thể tải ảnh lên: $error'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<XFile?> _cropImage(XFile picked) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Chỉnh ảnh minh chứng',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Chỉnh ảnh minh chứng',
          doneButtonTitle: 'Xong',
          cancelButtonTitle: 'Hủy',
        ),
        WebUiSettings(
          context: context,
          // Trang riêng tránh lỗi layout của cropper dialog ở cửa sổ Web hẹp.
          presentStyle: WebPresentStyle.page,
          dragMode: WebDragMode.move,
          viewwMode: WebViewMode.mode_1,
          checkCrossOrigin: false,
          checkOrientation: false,
          zoomOnWheel: true,
          cropBoxMovable: true,
          cropBoxResizable: true,
        ),
      ],
    );
    if (croppedFile == null) return null;

    return XFile.fromData(
      await croppedFile.readAsBytes(),
      name: croppedFile.path.split(RegExp(r'[/\\]')).last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);
    ShiftModel? booking;
    for (final b in shifts) {
      if (b.id == widget.id) {
        booking = b;
        break;
      }
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ca đang diễn ra'),
          leading: const AppBackButton(fallbackRoute: '/shifts'),
        ),
        body: const Center(
          child: Text('Không tìm thấy thông tin ca làm việc này.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ),
      );
    }

    if (!_didRestoreServerState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreFromServerState(booking!);
      });
    }
    if (!_didRequestTasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTasks();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ca đang diễn ra'),
        leading: const AppBackButton(fallbackRoute: '/shifts'),
        actions: [
          // Live timer chip (visible after check-in)
          if (_isCheckedIn)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _elapsedLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            tooltip: 'Báo cáo sự cố',
            onPressed: _showIncidentReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Check-in section ──
            _isCheckedIn ? _buildCheckedInBadge() : _buildCheckInFlow(booking),
            const SizedBox(height: 24),

            // ── Checklist ──
            _buildChecklistSection(context, booking),

            // ── Caregiver note ──
            if (_isCheckedIn) ...[
              const SizedBox(height: 24),
              _buildNoteSection(),
            ],

            // ── Progress bar ──
            if (_isCheckedIn && booking.tasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildProgressBar(booking),
            ],

            const SizedBox(height: 24),

            // ── Check-out button ──
            if (_isCheckedIn) _buildCheckOutButton(booking),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // CHECK-IN FLOW — 3 animated steps
  // ════════════════════════════════════════════════════════
  Widget _buildCheckInFlow(ShiftModel booking) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Step indicator bar
          _buildStepBar(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _stepFade,
              child: _buildStepContent(booking),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBar() {
    const labels = ['Selfie', 'GPS', 'Xác nhận'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: List.generate(3, (i) {
          final stepNum = i + 1;
          final isDone = _checkInStep > stepNum;
          final isCurrent = _checkInStep == stepNum;
          return Expanded(
            child: Row(
              children: [
                // Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.success
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.border,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : Text(
                            '$stepNum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  isCurrent ? Colors.white : AppColors.textHint,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCurrent || isDone
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                // Connector
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? AppColors.success : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(ShiftModel booking) {
    switch (_checkInStep) {
      case 0:
        return _buildStep0Start(booking);
      case 1:
        return _buildStep1Selfie();
      case 2:
        return _buildStep2GPS(booking);
      case 3:
        return _buildStep3Confirm();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 0 — Not started
  Widget _buildStep0Start(ShiftModel booking) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Địa chỉ ca làm việc',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      booking.address,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Bạn đã đến nơi chưa?',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Thực hiện check-in để bắt đầu ca làm việc\nvà ghi lại minh chứng có mặt.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Bắt đầu Check-in'),
            onPressed: _advanceStep,
          ),
        ),
      ],
    );
  }

  // Step 1 — Selfie
  Widget _buildStep1Selfie() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_retouching_natural_rounded,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text('Khung chụp selfie',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Chụp ảnh selfie tại địa điểm',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ảnh selfie sẽ được gửi tới khách hàng\nnhư minh chứng bạn đã đến đúng địa điểm.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Thư viện'),
                onPressed: _advanceStep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Chụp ảnh'),
                onPressed: _advanceStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 2 — GPS
  Widget _buildStep2GPS(ShiftModel booking) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryContainer,
                AppColors.primary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📍 Vị trí GPS hiện tại',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    Text(
                      booking.address,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Yêu cầu GPS chính xác trong 50m',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Xác nhận vị trí GPS',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Vị trí hiện tại sẽ được máy chủ xác thực\ntrong phạm vi 50m của địa chỉ khách hàng.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isSubmittingCheckIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_isSubmittingCheckIn
                ? 'Đang xác thực GPS...'
                : 'Xác nhận vị trí'),
            onPressed:
                _isSubmittingCheckIn ? null : () => _confirmGpsCheckIn(booking),
          ),
        ),
      ],
    );
  }

  // Step 3 — Confirm (auto-complete)
  Widget _buildStep3Confirm() {
    return Column(
      children: [
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 56),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Check-in thành công!',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Thông tin check-in đã được ghi lại\nvà gửi tới khách hàng.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Checked-in badge (after done) ────────────────────────
  Widget _buildCheckedInBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F8F0), Color(0xFFF0FBF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Đã Check-in',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
                Text(
                  'Lúc $_checkInTimeLabel • GPS đã được xác thực • Đã selfie',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Live timer
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Đang làm',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                _elapsedLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress bar ─────────────────────────────────────────
  Widget _buildProgressBar(ShiftModel booking) {
    final done = booking.tasks.where((t) => t.isResolved).length;
    final total = booking.tasks.length;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Tiến độ hoàn thành',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            Text('${(ratio * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ── Checklist section (header + list + add-task button) ─────────────────
  Widget _buildChecklistSection(BuildContext context, ShiftModel booking) {
    final completedCount = booking.tasks.where((t) => t.isCompleted).length;
    final skippedCount = booking.tasks.where((t) => t.isSkipped).length;
    final total = booking.tasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const Text(
              'Checklist công việc',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            if (total > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount == total
                      ? AppColors.successLight
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completedCount / $total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: completedCount == total
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        if (!_isCheckedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  'Checklist sẽ mở sau khi bạn check-in.',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        if (skippedCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$skippedCount việc không thực hiện được',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        const SizedBox(height: 12),

        // Task items
        if (booking.tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Không có checklist công việc đặc biệt.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          )
        else
          ...booking.tasks
              .toList()
              .map((task) => _buildChecklistItem(booking, task)),

        // ➕ Add task button (only when checked-in + package allows)
        if (_isCheckedIn && booking.allowAdHocTasks)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showAddTaskSheet(booking),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm việc phát sinh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
      ],
    );
  }

  // ── Checklist item ────────────────────────────────────────
  Widget _buildChecklistItem(ShiftModel booking, CareTaskModel task) {
    final urls =
        _taskPhotos[task.id] ?? _taskPhotos[task.title] ?? task.photoUrls;
    final hasPhoto = urls.isNotEmpty;
    final isSkipped = task.isSkipped;
    final isLocked = _submittingTaskIds.contains(task.id);
    final canAct = _isCheckedIn && !task.isTerminal && !isLocked;

    Color cardBg = AppColors.cardBackground;
    Color borderColor = AppColors.border;
    if (task.isCompleted) {
      cardBg = AppColors.success.withValues(alpha: 0.05);
      borderColor = AppColors.success.withValues(alpha: 0.3);
    } else if (isSkipped) {
      cardBg = AppColors.warning.withValues(alpha: 0.05);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Checkbox / status icon ─────────────────
              GestureDetector(
                onTap: canAct && (!task.requiresPhoto || hasPhoto)
                    ? () => _onCompleteTask(booking, task)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? AppColors.success
                        : isSkipped
                            ? AppColors.warning.withValues(alpha: 0.2)
                            : canAct
                                ? AppColors.primaryContainer
                                : AppColors.border.withValues(alpha: 0.5),
                    border: Border.all(
                      color: task.isCompleted
                          ? AppColors.success
                          : isSkipped
                              ? AppColors.warning
                              : canAct
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: isLocked
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : task.isCompleted
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : isSkipped
                              ? const Icon(Icons.remove_rounded,
                                  size: 14, color: AppColors.warning)
                              : null,
                ),
              ),

              // ── Content ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: task.isTerminal
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isTerminal
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Source badge (ad-hoc)
                        if (task.isAdHoc)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Phát sinh',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        // Required badge
                        if (task.isRequired && !task.isTerminal)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'Bắt buộc',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    // Subtitle
                    if (isSkipped && task.skipReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Bỏ qua: ${task.skipReason}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.warning),
                        ),
                      )
                    else if (task.requiresPhoto &&
                        !hasPhoto &&
                        !task.isTerminal)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text(
                          'Upload ảnh minh chứng trước khi tick hoàn thành',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.warning),
                        ),
                      )
                    else if (task.description != null &&
                        task.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          task.description!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    // Photo row
                    if (hasPhoto)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.image_rounded,
                                size: 11, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text(
                              '${urls.length} ảnh đã đính kèm',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Action buttons ────────────────────────────
              if (!task.isTerminal)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo button
                    if (task.requiresPhoto)
                      IconButton(
                        icon: Icon(
                          hasPhoto
                              ? Icons.camera_alt_rounded
                              : Icons.camera_alt_outlined,
                          color:
                              hasPhoto ? AppColors.success : AppColors.textHint,
                          size: 20,
                        ),
                        tooltip:
                            hasPhoto ? 'Xem/đổi ảnh' : 'Chụp ảnh minh chứng',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _isCheckedIn
                            ? () => _pickTaskPhoto(booking, task)
                            : null,
                      ),
                    // Skip button (all tasks can be skipped, requires reason)
                    if (_isCheckedIn)
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded,
                            color: AppColors.textHint, size: 20),
                        tooltip: 'Bỏ qua công việc (cần ghi lý do)',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: isLocked
                            ? null
                            : () => _showSkipBottomSheet(booking, task),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Complete task (per-task lock) ─────────────────────────
  Future<void> _onCompleteTask(ShiftModel booking, CareTaskModel task) async {
    if (_submittingTaskIds.contains(task.id)) return;
    setState(() => _submittingTaskIds.add(task.id));
    try {
      await ref.read(shiftsProvider.notifier).completeTask(booking.id, task.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật công việc. Thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingTaskIds.remove(task.id));
    }
  }

  // ── Skip bottom sheet (all tasks, mandatory reason) ───────
  void _showSkipBottomSheet(ShiftModel booking, CareTaskModel task) {
    const reasons = [
      'Khách từ chối',
      'Không phù hợp điều kiện thực tế',
      'Gia đình đã tự thực hiện',
      'Khách vắng mặt / không thể phối hợp',
    ];
    String? selectedReason;
    final otherController = TextEditingController();
    bool isOther = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.skip_next_rounded,
                          color: AppColors.warning, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bỏ qua công việc',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text(task.title,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Chọn lý do bỏ qua:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                ...reasons.map((reason) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(reason, style: const TextStyle(fontSize: 13)),
                      value: reason,
                      groupValue: isOther ? null : selectedReason,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() {
                        selectedReason = val;
                        isOther = false;
                      }),
                    )),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Khác…', style: TextStyle(fontSize: 13)),
                  value: 'other',
                  groupValue: isOther ? 'other' : null,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setModalState(() {
                    isOther = true;
                    selectedReason = null;
                  }),
                ),
                if (isOther)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: otherController,
                      autofocus: true,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        hintText: 'Mô tả lý do…',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) =>
                          setModalState(() => selectedReason = val.trim()),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: selectedReason != null &&
                            selectedReason!.trim().isNotEmpty
                        ? () async {
                            final reason = selectedReason!.trim();
                            Navigator.pop(ctx);
                            setState(() => _submittingTaskIds.add(task.id));
                            try {
                              await ref
                                  .read(shiftsProvider.notifier)
                                  .skipTask(booking.id, task.id, reason);
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Không thể bỏ qua công việc. Thử lại.'),
                                    backgroundColor: AppColors.error),
                              );
                            } finally {
                              if (mounted) {
                                setState(
                                    () => _submittingTaskIds.remove(task.id));
                              }
                            }
                          }
                        : null,
                    child: const Text('Xác nhận bỏ qua',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(otherController.dispose);
  }

  // ── Add task bottom sheet ─────────────────────────────────
  void _showAddTaskSheet(ShiftModel booking) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm việc phát sinh',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                    'Việc bạn thêm sẽ được ghi nhận vào báo cáo cuối ca.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Tên công việc *',
                    hintText: 'Ví dụ: Đo huyết áp…',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    hintText: 'Mô tả thêm về công việc này…',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.length < 3) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Tên công việc phải ít nhất 3 ký tự.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ref
                                  .read(shiftsProvider.notifier)
                                  .createTask(
                                    booking.id,
                                    name,
                                    description: descController.text.trim(),
                                  );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                            } catch (_) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Không thể thêm việc. Thử lại.'),
                                    backgroundColor: AppColors.error),
                              );
                            } finally {
                              setModalState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Thêm việc',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
    });
  }

  // ── Caregiver note ────────────────────────────────────────
  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ghi chú cuối ca',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ghi chú sẽ hiện trong báo cáo gửi khách hàng',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ví dụ: Bé ăn được 1 bát cháo, ngủ trưa 1 tiếng\u2026',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // ── Check-out button ─────────────────────────────────────
  Widget _buildCheckOutButton(ShiftModel booking) {
    final pendingCount =
        booking.tasks.where((t) => t.status == 'PENDING').length;
    final requiredSkippedCount =
        booking.tasks.where((t) => t.isSkipped && t.isRequired).length;
    final canCheckout = pendingCount == 0;

    return Column(
      children: [
        if (pendingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Còn $pendingCount công việc chưa hoàn thành hoặc bỏ qua.',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        if (requiredSkippedCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$requiredSkippedCount công việc bắt buộc bỏ qua. '
                    'Ca sẽ được chuyển sang chế độ xét duyệt.',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: '\u2705  Hoàn thành ca & Check-out',
            onPressed: canCheckout
                ? () async {
                    try {
                      await ref.read(shiftsProvider.notifier).addTimelineNote(
                            booking.id,
                            _noteController.text,
                          );
                      await ref
                          .read(shiftsProvider.notifier)
                          .checkOut(booking.id);
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Chưa gửi được yêu cầu checkout: $error'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    if (!mounted) return;
                    context.go(
                      '/shifts/${booking.id}/summary',
                      extra: {
                        'beneficiaryName': booking.beneficiaryName,
                        'caregiverEarning': booking.caregiverEarning,
                        'completedTasks':
                            booking.tasks.where((t) => t.isCompleted).length,
                        'skippedTasks':
                            booking.tasks.where((t) => t.isSkipped).length,
                        'totalTasks': booking.tasks.length,
                        'duration': booking.duration,
                        'checkInTime': _checkInTimeLabel,
                        'caregiverNote': _noteController.text,
                        'taskPhotos': <dynamic>{
                          ..._taskPhotos.values.expand((urls) => urls),
                          ...booking.tasks.expand((task) => task.photoUrls),
                        }.toList(),
                        'checkoutPendingReview': true,
                      },
                    );
                  }
                : null,
          ),
        ),
      ],
    );
  }

  // ── Incident report ───────────────────────────────────────
  void _showIncidentReport() {
    final incidentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\uD83D\uDEA8 Báo cáo sự cố',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                  'Mô tả sự cố — hệ thống sẽ thông báo ngay đến khách hàng và admin.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: incidentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Mô tả vấn đề khẩn cấp\u2026',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Gửi báo cáo khẩn cấp',
                backgroundColor: AppColors.error,
                onPressed: () async {
                  try {
                    await ref.read(shiftsProvider.notifier).raiseSos(widget.id);
                    await ref.read(shiftsProvider.notifier).addTimelineNote(
                          widget.id,
                          incidentController.text,
                        );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Đã gửi báo cáo khẩn cấp đến khách hàng và admin.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  } catch (error) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text('Chưa gửi được báo cáo: $error'),
                          backgroundColor: AppColors.error),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(incidentController.dispose);
  }
}
