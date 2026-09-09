import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/realtime/care_signalr_service.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../booking/application/booking_store.dart';

class ShiftTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ShiftTrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ShiftTrackingScreen> createState() =>
      _ShiftTrackingScreenState();
}

class _ShiftTrackingScreenState extends ConsumerState<ShiftTrackingScreen> {
  // Vị trí caregiver — cập nhật qua SignalR GpsUpdated event
  late LatLng _caregiverPos;
  StreamSubscription<GpsUpdate>? _gpsSub;
  StreamSubscription<BookingStatusChange>? _statusSub;
  late final CareSignalRService _signalR;
  int _etaSeconds = 8 * 60; // ETA khởi tạo: 8 phút
  double _heading = 45.0;

  // Điểm xuất phát demo của caregiver (cách đích ~1.5km)
  static const _caregiverStart = LatLng(10.7640, 106.6780);

  @override
  void initState() {
    super.initState();
    _caregiverPos = _caregiverStart;
    _signalR = ref.read(careSignalRProvider);
    _connectSignalR();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _statusSub?.cancel();
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

      final dest = _coordsForAddress(bk.address);
      final distM = const Distance().as(
        LengthUnit.Meter,
        LatLng(gps.latitude, gps.longitude),
        dest,
      );
      setState(() {
        _caregiverPos = LatLng(gps.latitude, gps.longitude);
        _heading = gps.heading ?? _heading;
        final speedMs = (gps.speed ?? 6.9);
        _etaSeconds = speedMs > 0.5 ? (distM / speedMs).round() : _etaSeconds;
      });
    });

    // ── Lắng nghe booking status changes ─────────────────────────
    _statusSub = _signalR.statusStream
        .where((e) => e.bookingId == widget.bookingId)
        .listen((change) {
      if (!mounted) return;
      // Refresh booking store để UI cập nhật trạng thái
      ref.read(bookingStoreProvider.notifier).refresh();
    });
  }

  String get _etaLabel {
    final m = (_etaSeconds ~/ 60);
    final s = _etaSeconds % 60;
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
    final doneCount = bk.tasks.where((t) {
      try {
        return t.isCompleted == true;
      } catch (_) {
        return false;
      }
    }).length;
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
                    _buildProgressStrip(bk, doneCount, totalCount, progressPct),
                    const SizedBox(height: 14),
                    _buildTaskList(context, ref, bk),
                    const SizedBox(height: 14),
                    _buildCaregiverNote(bk),
                    const SizedBox(height: 14),
                  ],
                  _buildInfoRow(bk),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/bookings/$bookingId/timeline'),
                    icon: const Icon(Icons.timeline_outlined, size: 16),
                    label: const Text('Xem nhật ký chăm sóc'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
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
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: AppColors.success, size: 8),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Theo dõi ca chăm sóc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 8)
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
              color: Colors.white.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 8)
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }

  // ── Map section ────────────────────────────────────────────────────────────
  Widget _buildMapSection(BookingModel bk) {
    final destCoord = _coordsForAddress(bk.address);
    final isEnRoute = bk.status == 'caregiver_en_route';
    return SizedBox(
      height: isEnRoute ? 280 : 230, // cao hơn khi đang di chuyển
      child: Stack(
        children: [
          if (_useStaticMapFallback)
            _buildStaticMapPlaceholder(isEnRoute: isEnRoute)
          else
            RepaintBoundary(
              child: FlutterMap(
                key: ValueKey(bk.id),
                options: MapOptions(
                  initialCenter: isEnRoute
                      ? LatLng(
                          (_caregiverPos.latitude + destCoord.latitude) / 2,
                          (_caregiverPos.longitude + destCoord.longitude) / 2,
                        )
                      : destCoord,
                  initialZoom: isEnRoute ? 15 : 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.caresitter.customer',
                    tileBuilder: _mapTileBuilder,
                  ),
                  // Đường polyline từ caregiver đến nhà khách (en_route)
                  if (isEnRoute)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_caregiverPos, destCoord],
                          color: AppColors.primary.withValues(alpha: 0.55),
                          strokeWidth: 3.5,
                          pattern: const StrokePattern.dotted(),
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
                                    color: AppColors.primary.withOpacity(0.45),
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
                      if (isEnRoute)
                        Marker(
                          point: _caregiverPos,
                          width: 56,
                          height: 56,
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE67E22),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFE67E22).withOpacity(0.5),
                                  blurRadius: 18,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: _heading * 3.14159 / 180,
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Badge trạng thái (Trực tiếp / Đang di chuyển)
          Positioned(
            top: 60,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bk.status == 'caregiver_en_route'
                    ? const Color(0xFFE67E22).withOpacity(0.92)
                    : AppColors.primary.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Trực tiếp',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.14), blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _useStaticMapFallback {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  // ── Banner caregiver đang trên đường đến (en_route) ────────────────────────────────────────────
  Widget _buildEnRouteBanner(BookingModel bk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE67E22).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car_rounded,
                color: Color(0xFFE67E22), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caregiver đang trên đường đến',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE67E22)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${bk.caregiverName} · Dự kiến đến: $_etaLabel',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Pulsing dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, __) => Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE67E22).withOpacity(v),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Static map placeholder (web only) ──────────────────────────────────────
  Widget _buildStaticMapPlaceholder({bool isEnRoute = false}) {
    return Container(
      width: double.infinity,
      height: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDFF0EA), Color(0xFFB2D8CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_pin_circle,
                      color: Colors.white, size: 28),
                ),
                Container(width: 2, height: 14, color: AppColors.primary),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
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
                    Text(bk.caregiverName ?? 'Người chăm sóc',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Row(children: [
                      Icon(Icons.verified, color: AppColors.primary, size: 13),
                      SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          'CareConnect Certified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text('Chăm sóc: ${bk.beneficiaryName ?? "Người thân"}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.success.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('Đang làm',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('💬 Nhắn tin cho ${bk.caregiverName}...'),
                      backgroundColor: AppColors.primaryLight,
                      duration: const Duration(seconds: 2),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: const Text('Liên hệ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 Đang kết nối khẩn cấp...'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 2),
                  ),
                ),
                icon: const Icon(Icons.emergency_share_outlined, size: 15),
                label: const Text('SOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(96, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress strip ─────────────────────────────────────────────────────────
  Widget _buildProgressStrip(BookingModel bk, int done, int total, double pct) {
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
                  '${bk.serviceName} • ${bk.duration}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '$done / $total công việc hoàn thành',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withOpacity(0.25),
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
              Text(bk.time,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(bk.date,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Task list ──────────────────────────────────────────────────────────────
  Widget _buildTaskList(BuildContext context, WidgetRef ref, BookingModel bk) {
    final doneCount = bk.tasks.where((t) {
      try {
        return t.isCompleted == true;
      } catch (_) {
        return false;
      }
    }).length;
    final allDone = bk.tasks.isNotEmpty && doneCount == bk.tasks.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Công việc hôm nay',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
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
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bk.tasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có công việc nào',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ),
            )
          else
            ...bk.tasks.asMap().entries.map(
                  (entry) => _buildTaskRow(entry.value, entry.key, bk, ref),
                ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
      dynamic task, int index, BookingModel bk, WidgetRef ref) {
    final canToggle = bk.status == 'in_progress';
    final isDone = () {
      try {
        return task.isCompleted == true;
      } catch (_) {
        return false;
      }
    }();
    final taskTitle = () {
      try {
        return task.title?.toString() ?? 'Công việc';
      } catch (_) {
        return 'Công việc';
      }
    }();

    return InkWell(
      onTap: canToggle
          ? () =>
              ref.read(bookingStoreProvider.notifier).toggleTask(bk.id, index)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone ? AppColors.successLight : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : _iconForTask(taskTitle),
                color: isDone ? AppColors.success : AppColors.textHint,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                taskTitle,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isDone ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
            if (isDone)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: canToggle
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.textHint,
                size: 20,
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

  // ── Caregiver note ─────────────────────────────────────────────────────────
  Widget _buildCaregiverNote(BookingModel bk) {
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
                const Text('Ghi chú từ người chăm sóc',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB8860B))),
                const SizedBox(height: 4),
                Text(
                  '${bk.beneficiaryName} hôm nay tinh thần khá tốt. '
                  'Đã hoàn thành các bài tập nhẹ theo lịch.',
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
            child: _infoChip(Icons.person_outline, 'Người thân',
                bk.beneficiaryName ?? 'Người thân')),
        const SizedBox(width: 10),
        Expanded(
            child: _infoChip(Icons.access_time_outlined, 'Ca làm',
                '${bk.time} • ${bk.duration}')),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Extend shift sheet ─────────────────────────────────────────────────────
  void _showExtendShiftSheet(BuildContext context, BookingModel bk) {
    int selectedHours = 1;
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('Gia hạn ca chăm sóc',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text(
                'Yêu cầu sẽ được gửi đến người chăm sóc.\nCa gia hạn bắt đầu ngay sau ca hiện tại.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 32),
                      color: selectedHours > 1
                          ? AppColors.primary
                          : AppColors.textHint,
                      onPressed: selectedHours > 1
                          ? () => setSheetState(() => selectedHours--)
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          '$selectedHours',
                          style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                        const Text('giờ',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 32),
                      color: selectedHours < 4
                          ? AppColors.primary
                          : AppColors.textHint,
                      onPressed: selectedHours < 4
                          ? () => setSheetState(() => selectedHours++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payments_outlined,
                        size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Phí ước tính: ${_formatCurrency(selectedHours * 120000.0)}',
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
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
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Gửi yêu cầu gia hạn',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M ₫';
    }
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
                color: Colors.black.withOpacity(0.08),
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -3))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => ref
                    .read(bookingStoreProvider.notifier)
                    .caregiverRequestCheckout(bk.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, size: 15),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Demo: Mô phỏng caregiver kết thúc ca',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12),
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
                border: Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu không xác nhận, hệ thống sẽ tự hoàn tất sau 2 giờ kể từ khi ca kết thúc.',
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
            onPressed: () {
              ref.read(bookingStoreProvider.notifier).confirmCompleted(bk.id);
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã xác nhận hoàn thành ca! Cảm ơn bạn.'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 3),
                ),
              );
              popOrGo(context, fallbackRoute: '/bookings');
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
LatLng _coordsForAddress(String address) {
  if (address.contains('Nguyễn Trãi')) return const LatLng(10.7527, 106.6602);
  if (address.contains('Lê Lợi')) return const LatLng(10.7769, 106.7009);
  if (address.contains('Cách Mạng')) return const LatLng(10.7701, 106.6889);
  if (address.contains('Điện Biên')) return const LatLng(10.7870, 106.7160);
  return const LatLng(10.7769, 106.6952);
}

Widget _mapTileBuilder(
    BuildContext context, Widget tileWidget, TileImage tile) {
  return tileWidget;
}

// ── Map grid painter (web placeholder) ────────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        size.width.isInfinite ||
        size.height.isInfinite) {
      return;
    }
    final paint = Paint()
      ..color = const Color(0xFF27AE60).withOpacity(0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vẽ "đường phố" giả
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0),
        Offset(size.width * 0.7, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
