import 'package:caregiver_app/features/shifts/presentation/widgets/shift_route_map.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_route_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';
import 'package:caregiver_app/core/maps/map_tile_attribution.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_no_coordinates.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_movement_card.dart';

class ShiftMapScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String beneficiaryName;
  final String address;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const ShiftMapScreen({
    super.key,
    required this.bookingId,
    required this.beneficiaryName,
    required this.address,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  @override
  ConsumerState<ShiftMapScreen> createState() => _ShiftMapScreenState();
}

class _ShiftMapScreenState extends ConsumerState<ShiftMapScreen> {
  Position? _currentPosition;
  String? _locationError;
  bool _loadingLocation = true;

  LatLng? get _destination {
    final lat = widget.destinationLatitude;
    final lng = widget.destinationLongitude;
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  LocationStatus get _locationStatus {
    if (_loadingLocation) return const LocationLoading();
    if (_locationError != null) return LocationFailed(_locationError!);
    return const LocationReady();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _MapLocationException(
            'Hãy bật Dịch vụ vị trí để hiển thị vị trí hiện tại.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _MapLocationException(
            'Cần cấp quyền vị trí để hiển thị vị trí của bạn.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _MapLocationException(
            'Quyền vị trí đang bị tắt. Hãy bật lại trong Cài đặt của thiết bị.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPosition = position);
    } on _MapLocationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = 'Không thể lấy vị trí hiện tại.');
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    final destination = _destination;
    final query = destination == null
        ? Uri.encodeComponent(widget.address)
        : '${destination.latitude},${destination.longitude}';
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _distanceLabel(LatLng destination) {
    final current = _currentPosition;
    if (current == null) return null;
    final meters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destination.latitude,
      destination.longitude,
    );
    return meters < 1000
        ? 'Khoảng ${meters.round()} m đường thẳng'
        : 'Khoảng ${(meters / 1000).toStringAsFixed(1)} km đường thẳng';
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    if (destination == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Bản đồ đường đi'),
          leading: AppBackButton(fallbackRoute: '/shifts/${widget.bookingId}'),
        ),
        body: ShiftMapNoCoordinates(onOpenGoogleMaps: _openGoogleMaps),
      );
    }

    final tiles = ref.watch(mapTileConfigProvider);
    final current = _currentPosition == null
        ? null
        : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final center = current == null
        ? destination
        : LatLng((destination.latitude + current.latitude) / 2,
            (destination.longitude + current.longitude) / 2);
    final distance = _distanceLabel(destination);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bản đồ đường đi'),
        leading: AppBackButton(fallbackRoute: '/shifts/${widget.bookingId}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ShiftRouteMap(
                    center: center,
                    current: current,
                    ref: ref,
                    tiles: tiles,
                    destination: destination),
                ShiftRouteOverlay(
                    distance: distance,
                    locationStatus: _locationStatus,
                    loadCurrentPosition: _loadCurrentPosition,
                    openGoogleMaps: _openGoogleMaps,
                    routeBeneficiaryName: widget.beneficiaryName,
                    routeAddress: widget.address),
              ],
            ),
          ),
          MapTileAttribution(config: tiles),
        ],
      ),
    );
  }
}

class _MapLocationException implements Exception {
  final String message;
  const _MapLocationException(this.message);
}
