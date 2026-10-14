import 'live_map_viewport.dart';
import 'live_map_address_label.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_google_map.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_fallback_map.dart';
export 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_map_presentation_helpers.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:caresitter_customer/core/maps/google_maps_runtime.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

// Cho phép thay nguồn tile dự phòng (ví dụ cache hoặc nguồn dùng khi kiểm thử).

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
          padding: const EdgeInsets.fromLTRB(40, 124, 68, AppSpacing.hero),
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

  void _onGoogleCreated(google.GoogleMapController controller) {
    if (!mounted) return;
    _google = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBoth();
    });
  }

  void _onFallbackReady() {
    _osmReady = true;
    _fitBoth();
  }

  void _showBoth() {
    _pauseFollow();
    _fitBoth();
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
    final map = useGoogle
        ? LiveCaregiverGoogleMap(
            homeIcon: _homeIcon,
            position: _position,
            caregiverIcon: _caregiverIcon,
            destination: widget.destination,
            heading: widget.heading,
            stale: widget.stale,
            locationLabel: widget.locationLabel,
            onInteraction: (_) => _pauseFollow(),
            onCreated: _onGoogleCreated)
        : LiveCaregiverFallbackMap(
            mapController: _osm,
            tiles: tiles,
            position: _position,
            destination: widget.destination,
            stale: widget.stale,
            heading: widget.heading,
            onReady: _onFallbackReady,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) _pauseFollow();
            });
    return Column(children: [
      LiveMapViewport(
          map: map,
          availability: availability,
          useGoogle: useGoogle,
          tiles: tiles,
          locationLabel: widget.locationLabel,
          follow: _follow,
          hasPosition: widget.caregiverPosition != null,
          onResumeFollow: _resumeFollow,
          onFitBoth: _showBoth),
      LiveMapAddressLabel(routeAddressLabel: widget.addressLabel),
    ]);
  }
}
