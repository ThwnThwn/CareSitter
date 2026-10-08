import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:caresitter_customer/core/maps/google_maps_runtime.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/maps/map_tile_attribution.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

// Cho phép thay nguồn tile dự phòng (ví dụ cache hoặc nguồn dùng khi kiểm thử).
final trackingTileProviderProvider = Provider<osm.TileProvider?>((ref) => null);

class LiveCaregiverMap extends ConsumerStatefulWidget {
  final LatLng destination;
  final LatLng? caregiverPosition;
  final double? heading;
  final bool stale;
  final String locationLabel;
  final String addressLabel;

  const LiveCaregiverMap({
    super.key,
    required this.destination,
    required this.caregiverPosition,
    required this.locationLabel,
    required this.addressLabel,
    this.heading,
    this.stale = false,
  });

  @override
  ConsumerState<LiveCaregiverMap> createState() => _LiveCaregiverMapState();
}

class _LiveCaregiverMapState extends ConsumerState<LiveCaregiverMap>
    with SingleTickerProviderStateMixin {
  final _osm = osm.MapController();
  google.GoogleMapController? _google;
  bool _osmReady = false;
  bool _follow = true;
  LatLng? _position;
  LatLng? _from;
  LatLng? _to;
  late final AnimationController _animation;
  google.BitmapDescriptor? _caregiverIcon;
  google.BitmapDescriptor? _homeIcon;

  @override
  void initState() {
    super.initState();
    _position = widget.caregiverPosition;
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_tick);
    unawaited(_loadIcons());
  }

  Future<void> _loadIcons() async {
    final caregiver = await _markerIcon(home: false);
    final home = await _markerIcon(home: true);
    if (mounted) {
      setState(() {
        _caregiverIcon = caregiver;
        _homeIcon = home;
      });
    }
  }

  static Future<google.BitmapDescriptor> _markerIcon(
      {required bool home}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(const Offset(36, 36), 32, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(36, 36), 28, Paint()..color = AppColors.primary);
    final shape = ui.Path();
    if (home) {
      shape.moveTo(20, 34);
      shape.lineTo(36, 20);
      shape.lineTo(52, 34);
      shape.lineTo(48, 34);
      shape.lineTo(48, 50);
      shape.lineTo(40, 50);
      shape.lineTo(40, 39);
      shape.lineTo(32, 39);
      shape.lineTo(32, 50);
      shape.lineTo(24, 50);
      shape.lineTo(24, 34);
    } else {
      shape.moveTo(36, 18);
      shape.lineTo(52, 52);
      shape.lineTo(36, 44);
      shape.lineTo(20, 52);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(72, 72);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    rendered.dispose();
    return google.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        width: 36, height: 36);
  }

  @override
  void didUpdateWidget(LiveCaregiverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.caregiverPosition;
    if (next == oldWidget.caregiverPosition) return;
    _animation.stop();
    if (next == null ||
        _position == null ||
        MediaQuery.disableAnimationsOf(context)) {
      _position = next;
    } else {
      _from = _position;
      _to = next;
      _animation.forward(from: 0);
    }
    if (_follow && next != null && !widget.stale) {
      if (oldWidget.caregiverPosition == null) {
        _fitBoth();
      } else {
        _center(next);
      }
    }
  }

  void _tick() {
    if (!mounted || _from == null || _to == null) return;
    final t = Curves.easeOutCubic.transform(_animation.value);
    setState(() => _position = LatLng(
          _from!.latitude + (_to!.latitude - _from!.latitude) * t,
          _from!.longitude + (_to!.longitude - _from!.longitude) * t,
        ));
  }

  void _pauseFollow() {
    if (_follow && mounted) setState(() => _follow = false);
  }

  Future<void> _animateGoogle(google.CameraUpdate update) async {
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        await _google?.moveCamera(update);
      } else {
        await _google?.animateCamera(update);
      }
    } catch (_) {/* Bản đồ có thể bị đóng trong lúc camera đang chuyển động. */}
  }

  void _center(LatLng point) {
    unawaited(_animateGoogle(google.CameraUpdate.newLatLng(
        google.LatLng(point.latitude, point.longitude))));
    if (_osmReady) _osm.move(point, _osm.camera.zoom);
  }

  void _fitBoth() {
    final caregiver = widget.caregiverPosition;
    if (caregiver == null ||
        const Distance().as(LengthUnit.Meter, caregiver, widget.destination) <
            10) {
      _center(widget.destination);
      return;
    }
    final points = [widget.destination, caregiver];
    if (_osmReady) {
      _osm.fitCamera(osm.CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(40, 124, 68, 64),
          maxZoom: 16));
    }
    final south = math.min(widget.destination.latitude, caregiver.latitude);
    final north = math.max(widget.destination.latitude, caregiver.latitude);
    final west = math.min(widget.destination.longitude, caregiver.longitude);
    final east = math.max(widget.destination.longitude, caregiver.longitude);
    // Tránh bounds có chiều rộng/cao bằng 0 khi hai điểm cùng kinh/vĩ độ.
    unawaited(_animateGoogle(google.CameraUpdate.newLatLngBounds(
        google.LatLngBounds(
            southwest: google.LatLng(south - .0001, west - .0001),
            northeast: google.LatLng(north + .0001, east + .0001)),
        32)));
  }

  void _resumeFollow() {
    setState(() => _follow = true);
    final point = widget.caregiverPosition;
    if (point != null) _center(point);
  }

  @override
  void dispose() {
    _animation.dispose();
    _osm.dispose();
    // GoogleMap sở hữu controller và tự dispose khi platform view bị đóng.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(googleMapsReadyProvider);
    final tiles = ref.watch(mapTileConfigProvider);
    final useGoogle = availability.valueOrNull == true;
    if (useGoogle) {
      _osmReady = false;
    } else {
      _google = null;
    }
    return Column(children: [
      Expanded(
          child: Stack(children: [
        Positioned.fill(
            child: availability.isLoading
                ? const ColoredBox(
                    color: AppColors.primaryContainer,
                    child: Center(child: CircularProgressIndicator()))
                : useGoogle
                    ? _googleMap()
                    : _fallbackMap()),
        Positioned(
          top: 12,
          left: 12,
          right: 68,
          child: PointerInterceptor(
              child: DecoratedBox(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.locationLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (!useGoogle) ...[
                      const SizedBox(height: 3),
                      Text(
                          availability.isLoading
                              ? 'Đang mở Google Maps...'
                              : tiles.label,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ]),
            ),
          )),
        ),
        Positioned(
            top: 12,
            right: 12,
            child: PointerInterceptor(
                child: Column(children: [
              _mapButton(
                  key: const Key('tracking-follow'),
                  tooltip: _follow
                      ? 'Đang bám theo chăm sóc viên'
                      : 'Theo dõi chăm sóc viên',
                  icon: Icons.my_location,
                  active: _follow && widget.caregiverPosition != null,
                  onPressed:
                      widget.caregiverPosition == null ? null : _resumeFollow),
              const SizedBox(height: 8),
              _mapButton(
                  key: const Key('tracking-fit-both'),
                  tooltip: 'Xem cả hai điểm',
                  icon: Icons.zoom_out_map,
                  onPressed: () {
                    _pauseFollow();
                    _fitBoth();
                  }),
            ]))),
      ])),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.location_on_outlined,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(widget.addressLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4))),
        ]),
      ),
    ]);
  }

  Widget _googleMap() => Listener(
        // Camera tự animate cũng phát onCameraMoveStarted. Chỉ thao tác của người
        // dùng mới tắt follow, tránh camera tự tắt follow sau mỗi mẫu GPS.
        onPointerDown: (_) => _pauseFollow(),
        child: google.GoogleMap(
          key: const Key('google-live-caregiver-map'),
          initialCameraPosition: google.CameraPosition(
              target: google.LatLng(
                  widget.destination.latitude, widget.destination.longitude),
              zoom: 15),
          onMapCreated: (controller) {
            if (!mounted) return;
            _google = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitBoth();
            });
          },
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          tiltGesturesEnabled: false,
          // Chừa chỗ cho nhãn GPS và hai nút, để fit bounds không che marker.
          padding: const EdgeInsets.only(top: 76, right: 36),
          markers: {
            google.Marker(
                markerId: const google.MarkerId('destination'),
                position: google.LatLng(
                    widget.destination.latitude, widget.destination.longitude),
                icon: _homeIcon ??
                    google.BitmapDescriptor.defaultMarkerWithHue(
                        google.BitmapDescriptor.hueCyan),
                anchor: const Offset(.5, .5),
                infoWindow: const google.InfoWindow(title: 'Địa chỉ chăm sóc')),
            if (_position != null)
              google.Marker(
                  markerId: const google.MarkerId('caregiver'),
                  position:
                      google.LatLng(_position!.latitude, _position!.longitude),
                  icon: _caregiverIcon ??
                      google.BitmapDescriptor.defaultMarkerWithHue(
                          google.BitmapDescriptor.hueGreen),
                  anchor: const Offset(.5, .5),
                  flat: true,
                  rotation: widget.heading ?? 0,
                  alpha: widget.stale ? .5 : 1,
                  infoWindow: google.InfoWindow(
                      title: 'Chăm sóc viên', snippet: widget.locationLabel)),
          },
        ),
      );

  Widget _fallbackMap() {
    final tiles = ref.watch(mapTileConfigProvider);
    return osm.FlutterMap(
      key: const Key('fallback-live-caregiver-map'),
      mapController: _osm,
      options: osm.MapOptions(
          initialCenter: widget.destination,
          initialZoom: 15,
          onMapReady: () {
            _osmReady = true;
            _fitBoth();
          },
          onPositionChanged: (_, hasGesture) {
            if (hasGesture) _pauseFollow();
          },
          interactionOptions: const osm.InteractionOptions(
              flags: osm.InteractiveFlag.pinchZoom | osm.InteractiveFlag.drag)),
      children: [
        osm.TileLayer(
            tileProvider: ref.watch(trackingTileProviderProvider),
            urlTemplate: tiles.urlTemplate,
            subdomains: tiles.subdomains,
            retinaMode: tiles.usesCarto,
            maxNativeZoom: tiles.maxNativeZoom,
            userAgentPackageName: 'vn.caresitter.customer'),
        osm.MarkerLayer(markers: [
          osm.Marker(
              point: widget.destination,
              width: 42,
              height: 42,
              child: _pin(Icons.home_rounded)),
          if (_position != null)
            osm.Marker(
                point: _position!,
                width: 42,
                height: 42,
                child: Opacity(
                    opacity: widget.stale ? .5 : 1,
                    child: Transform.rotate(
                        angle: (widget.heading ?? 0) * math.pi / 180,
                        child: _pin(Icons.navigation_rounded)))),
        ]),
        Align(
            alignment: Alignment.bottomLeft,
            child: MapTileAttribution(config: tiles)),
      ],
    );
  }

  Widget _pin(IconData icon) => DecoratedBox(
      decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3)),
      child: Icon(icon, color: Colors.white, size: 22));

  Widget _mapButton(
          {required Key key,
          required String tooltip,
          required IconData icon,
          VoidCallback? onPressed,
          bool active = false}) =>
      Material(
        color: active ? AppColors.primaryContainer : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border)),
        child: IconButton(
            key: key,
            tooltip: tooltip,
            onPressed: onPressed,
            color: AppColors.primary,
            icon: Icon(icon, size: 21),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
      );
}
