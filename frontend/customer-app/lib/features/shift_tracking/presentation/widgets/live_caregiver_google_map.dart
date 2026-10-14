import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

class LiveCaregiverGoogleMap extends StatelessWidget {
  const LiveCaregiverGoogleMap(
      {super.key,
      required this.homeIcon,
      required this.position,
      required this.caregiverIcon,
      required this.destination,
      required this.heading,
      required this.stale,
      required this.locationLabel,
      required this.onInteraction,
      required this.onCreated});
  final google.BitmapDescriptor? homeIcon;
  final LatLng? position;
  final google.BitmapDescriptor? caregiverIcon;
  final LatLng destination;
  final double? heading;
  final bool stale;
  final String locationLabel;
  final void Function(PointerDownEvent) onInteraction;
  final void Function(google.GoogleMapController) onCreated;
  @override
  Widget build(BuildContext context) => Listener(
        // Camera tự animate cũng phát onCameraMoveStarted. Chỉ thao tác của người
        // dùng mới tắt follow, tránh camera tự tắt follow sau mỗi mẫu GPS.
        onPointerDown: onInteraction,
        child: google.GoogleMap(
          key: const Key('google-live-caregiver-map'),
          initialCameraPosition: google.CameraPosition(
              target:
                  google.LatLng(destination.latitude, destination.longitude),
              zoom: 15),
          onMapCreated: onCreated,
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
                position:
                    google.LatLng(destination.latitude, destination.longitude),
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
                  rotation: heading ?? 0,
                  alpha: stale ? .5 : 1,
                  infoWindow: google.InfoWindow(
                      title: 'Chăm sóc viên', snippet: locationLabel)),
          },
        ),
      );
}
