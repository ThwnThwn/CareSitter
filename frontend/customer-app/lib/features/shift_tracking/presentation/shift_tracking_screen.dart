import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
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

  // Điểm fallback của caregiver khi chưa nhận được GPS mới nhất từ backend.
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
                    icon: const Icon(Icons.history_edu_outlined, size: 18),
                    label: const Text('Xem nhật ký chăm sóc'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.2),
                      backgroundColor: const Color(0xFFE8F5E9).withOpacity(0.5),
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
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
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
                  color: AppColors.primary.withOpacity(v),
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
            color: Colors.white.withOpacity(0.95),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border.withOpacity(0.8)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
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
              color: Colors.white.withOpacity(0.95),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border.withOpacity(0.8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
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
    final destCoord = _coordsForAddress(bk.address);
    final isEnRoute = bk.status == 'caregiver_en_route';
    return SizedBox(
      height: isEnRoute ? 280 : 230, // cao hơn khi đang di chuyển
      child: Stack(
        children: [
          if (_useStaticMapFallback)
            _buildStaticMapPlaceholder(isEnRoute: isEnRoute, bk: bk)
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
                          color: AppColors.primary.withValues(alpha: 0.65),
                          strokeWidth: 4,
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
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.5),
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
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border.withOpacity(0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
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
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withOpacity(0.8)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 10)
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
        color: const Color(0xFFFEF7EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF5A623).withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5A623).withOpacity(0.12),
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
                  color: const Color(0xFFF5A623).withOpacity(0.2),
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
                    color: const Color(0xFFF5A623).withOpacity(v),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5A623).withOpacity(v * 0.5),
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
              backgroundColor: const Color(0xFFF5A623).withOpacity(0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Static map placeholder (web & desktop) ──────────────────────────────────────
  Widget _buildStaticMapPlaceholder(
      {bool isEnRoute = false, required BookingModel bk}) {
    return Container(
      width: double.infinity,
      height: isEnRoute ? 280 : 230,
      decoration: const BoxDecoration(
        color: Color(0xFFE5ECE7),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _VectorMapPainter(isEnRoute: isEnRoute),
            ),
          ),
          // Destination Pin (Nhà khách)
          Positioned(
            left: 210,
            top: 68,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.7), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.home_rounded,
                          color: Colors.white, size: 11),
                      const SizedBox(width: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          'Nhà ${bk.beneficiaryName?.split(' ').last ?? 'khách'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                ),
              ],
            ),
          ),
          // Caregiver Moving Marker (en_route)
          if (isEnRoute)
            Positioned(
              left: 90,
              top: 130,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.2),
                    duration: const Duration(milliseconds: 1000),
                    builder: (_, scale, __) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.25),
                            ),
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              bk.caregiverInitials,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5A623),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.navigation_rounded,
                                size: 8, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E25),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Caregiver đang di chuyển',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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
        border: Border.all(color: AppColors.border, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2E25).withOpacity(0.05),
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
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: AppColors.primary, size: 12),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'CareConnect Certified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
          // Rating and metadata
          const Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              SizedBox(width: 3),
              Text(
                '4.98',
                style: TextStyle(
                  color: Color(0xFF805200),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  '(142 ca) • 4 năm kinh nghiệm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
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
          child: _infoCard(
            icon: Icons.person_outline_rounded,
            label: 'Người thân',
            value: bk.beneficiaryName ?? 'Người thân',
            subtext: 'Cụ ông • 78 tuổi',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _infoCard(
            icon: Icons.access_time_outlined,
            label: 'Ca làm',
            value: '${bk.time} • ${bk.duration}',
            subtext: 'Hôm nay, ${bk.date.isNotEmpty ? bk.date : "09/09/2026"}',
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
            color: Colors.black.withOpacity(0.04),
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
        border: Border.all(color: const Color(0xFFF5A623).withOpacity(0.3)),
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

  // ── Extend shift sheet ─────────────────────────────────────────────────────
  void _showExtendShiftSheet(BuildContext context, BookingModel bk) {
    int selectedHours = 1;
    // Dùng đơn giá hiệu lực của booking hiện tại để tránh lệch với backend.
    final bookedHours = bk.scheduledEnd.difference(bk.scheduledStart).inMinutes / 60;
    final effectiveHourlyRate = bookedHours > 0 ? bk.totalPrice / bookedHours : 0.0;
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
                      'Phí ước tính: ${_formatCurrency(selectedHours * effectiveHourlyRate)}',
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
          children: const [
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
              color: Colors.black.withOpacity(0.06),
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

// ── Vector map painter (web & desktop placeholder) ───────────────────────────
class _VectorMapPainter extends CustomPainter {
  final bool isEnRoute;
  const _VectorMapPainter({this.isEnRoute = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Base canvas background
    final bgPaint = Paint()..color = const Color(0xFFE5ECE7);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Green Parks & Natural Zones
    final parkPaint = Paint()
      ..color = const Color(0xFFD2E8DA)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * 0.42, size.height * 0.32),
        const Radius.circular(16),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.58, size.width * 0.38,
            size.height * 0.42),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    // 3. Water Canal with gentle curved ribbon
    final waterPaint = Paint()
      ..color = const Color(0xFFBCE3DF)
      ..style = PaintingStyle.fill;
    final riverPath = Path();
    riverPath.moveTo(0, size.height * 0.82);
    riverPath.cubicTo(
      size.width * 0.25,
      size.height * 0.78,
      size.width * 0.45,
      size.height * 0.88,
      size.width * 0.75,
      size.height * 0.80,
    );
    riverPath.cubicTo(
      size.width * 0.90,
      size.height * 0.76,
      size.width,
      size.height * 0.84,
      size.width,
      size.height * 0.84,
    );
    riverPath.lineTo(size.width, size.height * 0.94);
    riverPath.cubicTo(
      size.width * 0.88,
      size.height * 0.88,
      size.width * 0.75,
      size.height * 0.90,
      size.width * 0.45,
      size.height * 0.96,
    );
    riverPath.cubicTo(
      size.width * 0.25,
      size.height * 0.88,
      0,
      size.height * 0.92,
      0,
      size.height * 0.92,
    );
    riverPath.close();
    canvas.drawPath(riverPath, waterPaint);

    // 4. City Blocks / Buildings (Light soft rects)
    final blockPaint = Paint()
      ..color = const Color(0xFFF9FAF8)
      ..style = PaintingStyle.fill;
    final blockBorder = Paint()
      ..color = const Color(0xFFD3DFD7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final blocks = [
      Rect.fromLTWH(16, 16, 42, 32),
      Rect.fromLTWH(68, 20, 36, 28),
      Rect.fromLTWH(116, 14, 52, 38),
      Rect.fromLTWH(size.width - 70, 24, 48, 32),
      Rect.fromLTWH(20, 110, 44, 34),
      Rect.fromLTWH(size.width - 80, 100, 56, 40),
    ];
    for (final b in blocks) {
      final r = RRect.fromRectAndRadius(b, const Radius.circular(6));
      canvas.drawRRect(r, blockPaint);
      canvas.drawRRect(r, blockBorder);
    }

    // 5. Street Network
    final roadBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadSurfacePaint = Paint()
      ..color = const Color(0xFFEAEFE9)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35), roadBorderPaint);
    canvas.drawLine(Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.35), roadSurfacePaint);

    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.45, 0),
        Offset(size.width * 0.45, size.height), roadBorderPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0),
        Offset(size.width * 0.45, size.height), roadSurfacePaint);

    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.35),
        Offset(size.width * 0.18, size.height), roadBorderPaint);
    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.35),
        Offset(size.width * 0.18, size.height), roadSurfacePaint);

    // 6. Navigation Route (Caregiver -> Destination)
    if (isEnRoute) {
      final routePath = Path();
      routePath.moveTo(105, 145);
      routePath.quadraticBezierTo(
          size.width * 0.35, 145, size.width * 0.45, 120);
      routePath.lineTo(size.width * 0.45, size.height * 0.35);
      routePath.lineTo(225, size.height * 0.35);

      final routeGlow = Paint()
        ..color = AppColors.primary.withOpacity(0.35)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(routePath, routeGlow);

      final routeLine = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(routePath, routeLine);
    }
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) =>
      oldDelegate.isEnRoute != isEnRoute;
}
