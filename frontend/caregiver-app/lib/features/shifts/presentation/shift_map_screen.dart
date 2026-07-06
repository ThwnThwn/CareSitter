import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';

class ShiftMapScreen extends StatelessWidget {
  final String bookingId;
  final String beneficiaryName;
  final String address;

  const ShiftMapScreen({
    super.key,
    required this.bookingId,
    required this.beneficiaryName,
    required this.address,
  });

  // Coordinates mapping based on address hints (or standard fallback to central HCMC)
  LatLng get _targetCoords {
    if (address.contains('Nguyễn Trãi')) {
      return const LatLng(10.7554, 106.6710); // District 5
    }
    if (address.contains('Lê Lợi')) {
      return const LatLng(10.7715, 106.6975); // District 3 / 1
    }
    return const LatLng(10.7626, 106.6602); // Central fallback
  }

  // Caregiver's location (stubbed near target for routing effect)
  LatLng get _caregiverCoords {
    final target = _targetCoords;
    return LatLng(target.latitude + 0.015, target.longitude - 0.012);
  }

  Future<void> _openGoogleMaps() async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetCoords;
    final cgPos = _caregiverCoords;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bản đồ đường đi'),
        leading: AppBackButton(fallbackRoute: '/shifts/$bookingId'),
      ),
      body: Stack(
        children: [
          // ── Flutter Map View ──
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (target.latitude + cgPos.latitude) / 2,
                (target.longitude + cgPos.longitude) / 2,
              ),
              initialZoom: 13.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.caresitter.caregiver',
              ),
              // Route Line
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [cgPos, target],
                    color: AppColors.primary,
                    strokeWidth: 4.5,
                  ),
                ],
              ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Caregiver Marker
                  Marker(
                    point: cgPos,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: AppShadows.card,
                      ),
                      child: const Center(
                        child: Icon(Icons.navigation_rounded, color: AppColors.primary, size: 22),
                      ),
                    ),
                  ),
                  // Destination Marker
                  Marker(
                    point: target,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.error,
                          size: 36,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Điểm đến',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Bottom Panel ──
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Thông tin di chuyển',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '12 phút (3.5 km)',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Khách hàng: $beneficiaryName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Mở Google Maps chỉ đường',
                    icon: Icons.navigation_outlined,
                    onPressed: _openGoogleMaps,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
