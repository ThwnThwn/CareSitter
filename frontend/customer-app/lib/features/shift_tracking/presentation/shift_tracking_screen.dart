import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/realtime/care_signalr_service.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/widgets/app_toast.dart';
import '../../booking/application/booking_store.dart';

class ShiftTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ShiftTrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ShiftTrackingScreen> createState() =>
      _ShiftTrackingScreenState();
}

class _ShiftTrackingScreenState extends ConsumerState<ShiftTrackingScreen>
    with TickerProviderStateMixin {
  // Vị trí caregiver — cập nhật qua SignalR GpsUpdated event
  LatLng? _caregiverPos;
  StreamSubscription<GpsUpdate>? _gpsSub;
  StreamSubscription<BookingStatusChange>? _statusSub;
  StreamSubscription<void>? _reconnectSub;
  late final CareSignalRService _signalR;
  int? _etaSeconds;
  double? _heading;
  final MapController _mapController = MapController();
  final List<LatLng> _gpsHistory = [];
  late final AnimationController _pulseController;
  late final AnimationController _positionController;
  LatLng? _animatedCaregiverPos;
  LatLng? _positionFrom;
  LatLng? _positionTo;

  @override
  void initState() {
    super.initState();
    _signalR = ref.read(careSignalRProvider);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_onPositionAnimationTick);
    _connectSignalR();
    unawaited(
        ref.read(bookingStoreProvider.notifier).loadTasks(widget.bookingId));
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _statusSub?.cancel();
    _reconnectSub?.cancel();
    _pulseController.dispose();
    _positionController.dispose();
    _mapController.dispose();
    // Rời group khi thoát màn hình
    _signalR.leaveBooking(widget.bookingId).ignore();
    super.dispose();
  }

  Future<void> _connectSignalR() async {
    await _signalR.joinBooking(widget.bookingId);

    // ── Lắng nghe GPS updates ────────────────────────────────────
    _gpsSub = _signalR.gpsStream
        .where((e) => e.bookingId == widget.bookingId)
        .listen((gps) {
      if (!mounted) return;
      final bk = ref
          .read(bookingStoreProvider)
          .where((b) => b.id == widget.bookingId)
          .firstOrNull;
      if (bk == null) return;

      final dest = bk.addressLatitude == null || bk.addressLongitude == null
          ? null
          : LatLng(bk.addressLatitude!, bk.addressLongitude!);
      if (dest == null) return;
      final distM = const Distance().as(
        LengthUnit.Meter,
        LatLng(gps.latitude, gps.longitude),
        dest,
      );
      final next = LatLng(gps.latitude, gps.longitude);
      if (_gpsHistory.isEmpty || _gpsHistory.last != next) {
        _gpsHistory.add(next);
        if (_gpsHistory.length > 250) _gpsHistory.removeAt(0);
      }
      setState(() {
        _caregiverPos = next;
        _heading = gps.heading ?? _heading;
        final speedMs = gps.speed;
        _etaSeconds = speedMs != null && speedMs > 0.5
            ? (distM / speedMs).round()
            : _etaSeconds;
      });
      _animateCaregiverTo(next);
    });

    // ── Lắng nghe booking status changes ─────────────────────────
    _statusSub = _signalR.statusStream
        .where((e) => e.bookingId == widget.bookingId)
        .listen((change) {
      if (!mounted) return;
      // Refresh booking store để UI cập nhật trạng thái
      ref.read(bookingStoreProvider.notifier).refresh();
    });

    // ── Lắng nghe reconnect để load lại checklist ─────────────────
    _reconnectSub = _signalR.onReconnected.listen((_) {
      if (!mounted) return;
      ref.read(bookingStoreProvider.notifier).loadTasks(widget.bookingId);
    });
  }

  void _animateCaregiverTo(LatLng next) {
    final from = _animatedCaregiverPos ?? _caregiverPos ?? next;
    _positionFrom = from;
    _positionTo = next;
    _positionController
      ..stop()
      ..value = 0
      ..forward();
  }

  void _onPositionAnimationTick() {
    final from = _positionFrom;
    final to = _positionTo;
    if (!mounted || from == null || to == null) return;
    final t = Curves.easeOutCubic.transform(_positionController.value);
    final position = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    setState(() => _animatedCaregiverPos = position);
    try {
      _mapController.move(position, _mapController.camera.zoom);
    } catch (_) {
      // The first GPS update may arrive before FlutterMap attaches its controller.
    }
  }

  String get _etaLabel {
    final seconds = _etaSeconds;
    if (seconds == null) return 'Đang cập nhật';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s giây';
    return '$m phút ${s > 0 ? '$s giây' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = widget.bookingId;
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == bookingId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy booking')));
    }
    final bk = matches.first;

    // Màn theo dõi trực tiếp mở cho cả caregiver_en_route (caregiver đang di chuyển) và
    // in_progress / checkout_pending_review (ca đang diễn ra). Các trạng thái khác
    // vẫn hiển thị trang thông báo rõ ràng.
    const liveStatuses = {
      'caregiver_en_route',
      'in_progress',
      'checkout_pending_review'
    };
    if (!liveStatuses.contains(bk.status)) {
      return _buildNotLiveScaffold(context, bk);
    }
    final doneCount = bk.tasks.where((t) => t.isCompleted).length;
    final skippedCount = bk.tasks.where((t) => t.isSkipped).length;
    final totalCount = bk.tasks.length;
    final progressPct = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildFloatingAppBar(context),
      bottomNavigationBar: _BottomActionBar(bk: bk, bookingId: bookingId),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMapSection(bk),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  if (bk.status == 'caregiver_en_route') ...[
                    _buildEnRouteBanner(bk),
                    const SizedBox(height: 14),
                  ],
                  _buildCaregiverCard(context, bk),
                  const SizedBox(height: 14),
                  if (bk.status != 'caregiver_en_route') ...[
                    if (bk.needsReview ||
                        bk.tasks.any((t) => t.isRequired && t.isSkipped)) ...[
                      _buildNeedsReviewBanner(context, bk),
                      const SizedBox(height: 14),
                    ],
                    _buildProgressStrip(bk, doneCount, totalCount, progressPct,
                        skippedCount: skippedCount),
                    const SizedBox(height: 14),
                    _buildTaskList(context, ref, bk),
                    const SizedBox(height: 14),
                    if (bk.beneficiaryNotes?.trim().isNotEmpty == true) ...[
                      _buildFamilyNote(bk.beneficiaryNotes!.trim()),
                      const SizedBox(height: 14),
                    ],
                  ],
                  _buildInfoRow(bk),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/bookings/$bookingId/timeline'),
                    icon: const Icon(Icons.history_edu_outlined, size: 18),
                    label: const Text('Xem nhật ký chăm sóc'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                      backgroundColor:
                          const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTrustGuaranteeCard(),
                  if (bk.status == 'in_progress') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showExtendShiftSheet(context, bk),
                      icon: const Icon(Icons.more_time_outlined, size: 16),
                      label: const Text('Yêu cầu gia hạn ca'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fallback khi ca chưa/không còn ở trạng thái live ───────────────────────
  Widget _buildNotLiveScaffold(BuildContext context, BookingModel bk) {
    final info = _notLiveInfo(bk.status);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Theo dõi ca chăm sóc',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        leading: const AppBackButton(
          fallbackRoute: '/bookings',
          color: AppColors.textPrimary,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                info.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                info.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    popOrGo(context, fallbackRoute: '/bookings/${bk.id}'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(info.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, String title, String message, String actionLabel})
      _notLiveInfo(String status) {
    switch (status) {
      case 'pending':
        return (
          icon: Icons.hourglass_empty_rounded,
          title: 'Ca chưa bắt đầu',
          message:
              'Đang chờ người chăm sóc nhận ca. Bạn có thể theo dõi trực tiếp ngay khi ca bắt đầu.',
          actionLabel: 'Xem chi tiết lịch hẹn',
        );
      case 'confirmed':
      case 'caregiver_en_route':
        return (
          icon: Icons.directions_car_rounded,
          title: 'Caregiver chưa bắt đầu di chuyển',
          message:
              'Caregiver chưa khởi động hành trình. Màn hình Live Tracking sẽ tự mở khi họ bắt đầu di chuyển.',
          actionLabel: 'Xem chi tiết lịch hẹn',
        );
      case 'completed':
        return (
          icon: Icons.check_circle_outline_rounded,
          title: 'Ca đã hoàn thành',
          message: 'Ca chăm sóc này đã kết thúc. Xem lại chi tiết và đánh giá.',
          actionLabel: 'Xem chi tiết',
        );
      case 'disputed':
        return (
          icon: Icons.report_problem_outlined,
          title: 'Ca đang được xử lý khiếu nại',
          message:
              'Yêu cầu của bạn đang được xem xét. Xem chi tiết để biết cập nhật.',
          actionLabel: 'Xem chi tiết',
        );
      case 'cancelled':
        return (
          icon: Icons.cancel_outlined,
          title: 'Ca đã bị huỷ',
          message: 'Ca chăm sóc này đã bị huỷ.',
          actionLabel: 'Xem chi tiết',
        );
      default:
        return (
          icon: Icons.info_outline_rounded,
          title: 'Không thể theo dõi ca này',
          message: 'Trạng thái ca hiện không hỗ trợ theo dõi trực tiếp.',
          actionLabel: 'Xem chi tiết',
        );
    }
  }

  // ── Floating transparent AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildFloatingAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 900),
              builder: (_, v, __) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: v),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Theo dõi ca chăm sóc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
            ],
          ),
          child: const AppBackButton(
            fallbackRoute: '/bookings',
            color: AppColors.textPrimary,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
              ],
            ),
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      size: 20, color: AppColors.textPrimary),
                  onPressed: () {},
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Map section ────────────────────────────────────────────────────────────
  Widget _buildMapSection(BookingModel bk) {
    final destCoord = bk.addressLatitude == null || bk.addressLongitude == null
        ? null
        : LatLng(bk.addressLatitude!, bk.addressLongitude!);
    final isEnRoute = bk.status == 'caregiver_en_route';
    if (destCoord == null) {
      return _buildMapUnavailable();
    }
    return SizedBox(
      height: isEnRoute ? 280 : 230, // cao hơn khi đang di chuyển
      child: Stack(
        children: [
          RepaintBoundary(
            child: FlutterMap(
              key: ValueKey(bk.id),
              options: MapOptions(
                initialCenter:
                    _animatedCaregiverPos ?? _caregiverPos ?? destCoord,
                initialZoom: isEnRoute ? 15 : 16,
                onMapReady: () {
                  final position = _animatedCaregiverPos ?? _caregiverPos;
                  if (position != null) {
                    _mapController.move(position, isEnRoute ? 15 : 16);
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: true,
                  userAgentPackageName: 'com.caresitter.app',
                ),
                // Đường polyline từ caregiver đến nhà khách (en_route)
                if (_gpsHistory.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          ..._gpsHistory,
                          if (_animatedCaregiverPos != null)
                            _animatedCaregiverPos!,
                        ],
                        color: AppColors.primary.withValues(alpha: 0.65),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Marker nhà khách (đích đến)
                    Marker(
                      point: destCoord,
                      width: 56,
                      height: 68,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.home_rounded,
                                color: Colors.white, size: 22),
                          ),
                          Container(
                              width: 2, height: 10, color: AppColors.primary),
                        ],
                      ),
                    ),
                    // Marker Caregiver đang di chuyển (chỉ hiện khi en_route)
                    if ((_animatedCaregiverPos ?? _caregiverPos) != null)
                      Marker(
                        point: _animatedCaregiverPos ?? _caregiverPos!,
                        width: 82,
                        height: 92,
                        child: _buildLiveHomeMarker(),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Badge trạng thái (Trực tiếp / Đang di chuyển)
          Positioned(
            top: 60,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.podcasts, color: AppColors.primary, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Trực tiếp',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Address pill
          Positioned(
            bottom: 10,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.primary, size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        bk.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.primary, size: 10),
                          SizedBox(width: 3),
                          Text('Đã xác thực',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 12,
            bottom: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xDFFFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text('© CARTO',
                    style: TextStyle(fontSize: 9, color: Color(0xFF36514A))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHomeMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final scale = 0.72 + pulse * 0.62;
        final opacity = (1 - pulse) * 0.32;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: opacity),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.42),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 23),
                ),
                Container(width: 3, height: 11, color: AppColors.primary),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapUnavailable() {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: const Text(
        'Chưa có tọa độ địa chỉ để hiển thị bản đồ.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  // ── Banner caregiver đang trên đường đến (en_route) ────────────────────────────────────────────
  Widget _buildEnRouteBanner(BookingModel bk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF5A623).withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5A623).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF935200),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Caregiver đang trên đường đến',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: '${bk.caregiverName} · '),
                          const TextSpan(text: 'Dự kiến đến: '),
                          TextSpan(
                            text: '$_etaLabel (còn ~1.8 km)',
                            style: const TextStyle(
                              color: Color(0xFF935200),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withValues(alpha: v),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFF5A623).withValues(alpha: v * 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Micro progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.75,
              backgroundColor: const Color(0xFFF5A623).withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Caregiver card ─────────────────────────────────────────────────────────
  Widget _buildCaregiverCard(BuildContext context, BookingModel bk) {
    final caregiverAvatar = bk.caregiverAvatar ?? '';
    final avatarText = caregiverAvatar.isNotEmpty && caregiverAvatar.length <= 3
        ? caregiverAvatar
        : bk.caregiverInitials;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2E25).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bk.caregiverName ?? 'Người chăm sóc',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: const Text(
                        'Đang theo dõi ca chăm sóc',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chăm sóc: ${bk.beneficiaryName ?? "Người thân"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Đang làm',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('💬 Kết nối liên hệ với ${bk.caregiverName}...'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Liên hệ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('🚨 Đang kích hoạt tín hiệu SOS khẩn cấp 24/7...'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 3),
                  ),
                ),
                icon: const Icon(Icons.emergency_share_outlined, size: 16),
                label: const Text('SOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Needs review banner ───────────────────────────────────────────────────
  Widget _buildNeedsReviewBanner(BuildContext context, BookingModel bk) {
    final skippedRequiredCount =
        bk.tasks.where((t) => t.isRequired && t.isSkipped).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // amber.shade50
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE65100),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ca trực cần xem lại',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  skippedRequiredCount > 0
                      ? 'Có $skippedRequiredCount công việc bắt buộc không thể thực hiện trong ca. Người chăm sóc đã ghi rõ lý do bên dưới để gia đình tiện theo dõi.'
                      : 'Ca trực này có các công việc cần lưu ý xem xét.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5D4037),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress strip ─────────────────────────────────────────────────────────
  Widget _buildProgressStrip(
    BookingModel bk,
    int done,
    int total,
    double pct, {
    int skippedCount = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E6262), Color(0xFF297979)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bk.serviceName ?? "Dịch vụ"} • ${bk.duration}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$done / $total công việc hoàn thành',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (skippedCount > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '• $skippedCount việc không thực hiện được',
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 16),
              const SizedBox(height: 4),
              Text(
                bk.time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                bk.date,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Task list (Read-only) ──────────────────────────────────────────────────
  Widget _buildTaskList(BuildContext context, WidgetRef ref, BookingModel bk) {
    final doneCount = bk.tasks.where((t) => t.isCompleted).length;
    final skippedCount = bk.tasks.where((t) => t.isSkipped).length;
    final allDone = bk.tasks.isNotEmpty && doneCount == bk.tasks.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tiến độ chăm sóc',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (skippedCount > 0) ...[
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFFFB74D), width: 0.6),
                  ),
                  child: Text(
                    '$skippedCount bỏ qua',
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppColors.successLight
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$doneCount/${bk.tasks.length}',
                  style: TextStyle(
                    color: allDone ? AppColors.success : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bk.tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 36,
                    color: AppColors.textHint.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gói dịch vụ này chưa có checklist',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...bk.tasks.map((task) => _buildTaskRow(task, bk, context)),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
      CareTaskModel task, BookingModel bk, BuildContext context) {
    final isDone = task.isCompleted;
    final isSkipped = task.isSkipped;

    Color itemBg = AppColors.surfaceVariant.withValues(alpha: 0.3);
    Color borderColor = AppColors.border.withValues(alpha: 0.6);
    if (isDone) {
      itemBg = AppColors.successLight.withValues(alpha: 0.4);
      borderColor = AppColors.success.withValues(alpha: 0.25);
    } else if (isSkipped) {
      itemBg = const Color(0xFFFFF8E1).withValues(alpha: 0.7);
      borderColor = const Color(0xFFFFCC80).withValues(alpha: 0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 1, right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.success
                      : isSkipped
                          ? const Color(0xFFFFB74D)
                          : AppColors.surface,
                  border: Border.all(
                    color: isDone
                        ? AppColors.success
                        : isSkipped
                            ? const Color(0xFFE65100)
                            : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : isSkipped
                        ? const Icon(Icons.remove_rounded,
                            size: 16, color: Colors.white)
                        : Icon(
                            _iconForTask(task.title),
                            size: 14,
                            color: AppColors.textHint,
                          ),
              ),
              // Title and badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isDone ? FontWeight.w500 : FontWeight.w600,
                              color: isSkipped
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration:
                                  isSkipped ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (task.isAdHoc) ...[
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
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        if (task.isRequired && !task.isTerminal) ...[
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Skip reason banner
          if (isSkipped &&
              task.skipReason != null &&
              task.skipReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, left: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC80), width: 0.6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Color(0xFFE65100),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lý do: ${task.skipReason}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8D6E63),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Photos gallery
          if (task.photoUrls.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 38),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: task.photoUrls.map((url) {
                  return GestureDetector(
                    onTap: () => _showPhotoPreviewDialog(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 18,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // Completion timestamp
          if (isDone && task.completedAt != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 38),
              child: Text(
                'Hoàn thành lúc ${task.completedAt!.hour.toString().padLeft(2, '0')}:${task.completedAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPhotoPreviewDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(32),
                    color: Colors.black87,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white70, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Không thể tải ảnh',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForTask(String title) {
    final t = title.toLowerCase();
    if (t.contains('check-in') || t.contains('check in')) {
      return Icons.login_rounded;
    }
    if (t.contains('ăn') || t.contains('bữa')) {
      return Icons.restaurant_menu_outlined;
    }
    if (t.contains('tắm') || t.contains('vệ sinh')) {
      return Icons.shower_outlined;
    }
    if (t.contains('tập') || t.contains('lý liệu') || t.contains('vận động')) {
      return Icons.directions_walk_outlined;
    }
    if (t.contains('ngủ') || t.contains('nghỉ')) {
      return Icons.bed_outlined;
    }
    if (t.contains('báo cáo') || t.contains('kết thúc')) {
      return Icons.assignment_turned_in_outlined;
    }
    if (t.contains('uống') || t.contains('dùng')) {
      return Icons.local_cafe_outlined;
    }
    return Icons.task_alt_outlined;
  }

  // ── Note supplied by the customer/family when creating the booking ─────────
  Widget _buildFamilyNote(String note) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE090), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined,
              color: Color(0xFFD4A012), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ghi chú của gia đình',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB8860B))),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info chips ─────────────────────────────────────────────────────────────
  Widget _buildInfoRow(BookingModel bk) {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            icon: Icons.person_outline_rounded,
            label: 'Người thân',
            value: bk.beneficiaryName ?? 'Người thân',
            subtext: 'Thông tin người được chăm sóc',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            icon: Icons.access_time_outlined,
            label: 'Ca làm',
            value: '${bk.time} • ${bk.duration}',
            subtext: bk.date,
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustGuaranteeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7EC),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF935200), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cam kết Đồng hành Phi Y tế & Bảo hiểm CareSitter CareGuard 24/7',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A5812),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExtendShiftSheet(BuildContext context, BookingModel bk) {
    int selectedHours = 1;
    final bookedHours =
        bk.scheduledEnd.difference(bk.scheduledStart).inMinutes / 60;
    final effectiveHourlyRate =
        bookedHours > 0 ? bk.totalPrice / bookedHours : 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gia hạn ca chăm sóc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    onPressed: selectedHours > 1
                        ? () => setSheetState(() => selectedHours--)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  Text('$selectedHours giờ',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    onPressed: selectedHours < 4
                        ? () => setSheetState(() => selectedHours++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                  'Phí ước tính: ${_formatCurrency(selectedHours * effectiveHourlyRate)}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '✅ Đã gửi yêu cầu gia hạn $selectedHours giờ đến người chăm sóc.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: const Text('Gửi yêu cầu gia hạn'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )} ₫';
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────────
class _BottomActionBar extends ConsumerWidget {
  final BookingModel bk;
  final String bookingId;
  const _BottomActionBar({required this.bk, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (bk.status == 'checkout_pending_review') {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _confirmComplete(context, ref, bk),
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Xác nhận kết thúc ca',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/bookings/$bookingId/dispute'),
              icon: const Icon(Icons.report_problem_outlined,
                  color: AppColors.error, size: 15),
              label: const Text('Báo cáo vấn đề',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (bk.status == 'in_progress') {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3))
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 13, color: AppColors.textHint),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nút kết thúc mở sau khi người chăm sóc gửi báo cáo',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (bk.status == 'caregiver_en_route') {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('💬 Mở tin nhắn nhanh cho ${bk.caregiverName}...'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 2),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text(
                'Gửi lời nhắn nhanh cho Caregiver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('⚠️ Đang kết nối tổng đài giám sát viên 24/7...'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 2),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 13, color: AppColors.error),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Báo cáo sự cố hoặc liên hệ giám sát viên 24/7',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _confirmComplete(BuildContext context, WidgetRef ref, BookingModel bk) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Text('Xác nhận hoàn thành', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn xác nhận ca chăm sóc của ${bk.caregiverName} đã hoàn tất?',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu không xác nhận, hệ thống sẽ tự hoàn tất sau 24 giờ kể từ khi yêu cầu checkout được gửi.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Chưa',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(dCtx);
              AppToast.loading(context, 'Đang xác nhận hoàn tất ca…');
              try {
                await ref
                    .read(bookingStoreProvider.notifier)
                    .confirmCompleted(bk.id);
                if (!context.mounted) return;
                AppToast.success(
                    context, 'Ca chăm sóc đã được xác nhận hoàn tất.');
                popOrGo(context, fallbackRoute: '/bookings');
              } catch (_) {
                if (!context.mounted) return;
                AppToast.error(
                    context, 'Không thể xác nhận lúc này. Vui lòng thử lại.');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
