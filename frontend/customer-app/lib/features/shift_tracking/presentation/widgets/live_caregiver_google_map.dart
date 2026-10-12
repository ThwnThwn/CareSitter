import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

class LiveCaregiverGoogleMap extends StatelessWidget {
  const LiveCaregiverGoogleMap(
      {super.key,
      required this.homeIcon,
      required this.position,
      required this.caregiverIcon,
      required this.routeDestination,
      required this.routeHeading,
      required this.routeStale,
      required this.routeLocationLabel,
      required this.action1,
      required this.action2});
  final google.BitmapDescriptor? homeIcon;
  final LatLng? position;
  final google.BitmapDescriptor? caregiverIcon;
  final LatLng routeDestination;
  final double? routeHeading;
  final bool routeStale;
  final String routeLocationLabel;
  final void Function(PointerDownEvent) action1;
  final void Function(google.GoogleMapController) action2;
  @override
  Widget build(BuildContext context) => Listener(
        // Camera tự animate cũng phát onCameraMoveStarted. Chỉ thao tác của người
        // dùng mới tắt follow, tránh camera tự tắt follow sau mỗi mẫu GPS.
        onPointerDown: action1,
        child: google.GoogleMap(
          key: const Key('google-live-caregiver-map'),
          initialCameraPosition: google.CameraPosition(
              target: google.LatLng(
                  routeDestination.latitude, routeDestination.longitude),
              zoom: 15),
          onMapCreated: action2,
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
                    routeDestination.latitude, routeDestination.longitude),
                icon: homeIcon ??
                    google.BitmapDescriptor.defaultMarkerWithHue(
                        google.BitmapDescriptor.hueCyan),
                anchor: const Offset(.5, .5),
                infoWindow: const google.InfoWindow(title: 'Địa chỉ chăm sóc')),
            if (position != null)
              google.Marker(
                  markerId: const google.MarkerId('caregiver'),
                  position:
                      google.LatLng(position!.latitude, position!.longitude),
                  icon: caregiverIcon ??
                      google.BitmapDescriptor.defaultMarkerWithHue(
                          google.BitmapDescriptor.hueGreen),
                  anchor: const Offset(.5, .5),
                  flat: true,
                  rotation: routeHeading ?? 0,
                  alpha: routeStale ? .5 : 1,
                  infoWindow: google.InfoWindow(
                      title: 'Chăm sóc viên', snippet: routeLocationLabel)),
          },
        ),
      );
}
