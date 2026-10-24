import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';

final shiftCheckinControllerProvider = Provider<ShiftCheckinController>((ref) {
  return ShiftCheckinController(ref.read(shiftRepositoryProvider));
});

class ShiftCheckinController {
  final ShiftRepository _repository;

  const ShiftCheckinController(this._repository);

  Future<DateTime?> checkIn(String bookingId) async {
    final position = await _getCurrentPosition();
    final response = await _repository.checkIn(
      bookingId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
    return DateTime.tryParse(response['actualStart']?.toString() ?? '')
        ?.toLocal();
  }

  Future<String> uploadSelfie(String bookingId, XFile image) async {
    final response = await _repository.uploadCheckInSelfie(bookingId, image);
    final url = response['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Máy chủ không trả về ảnh selfie.');
    }
    return url;
  }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException(
        'Hãy bật Dịch vụ vị trí để check-in.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException(
        'Cần cấp quyền vị trí để check-in.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        'Quyền vị trí đang bị tắt. Hãy bật lại trong phần Cài đặt của thiết bị.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const LocationUnavailableException(
        'Chưa lấy được vị trí GPS mới. Hãy kiểm tra GPS rồi thử lại.',
      );
    }
  }
}

class LocationUnavailableException implements Exception {
  final String message;

  const LocationUnavailableException(this.message);

  @override
  String toString() => message;
}
