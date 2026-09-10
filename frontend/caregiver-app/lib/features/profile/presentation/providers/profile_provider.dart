import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../data/caregiver_profile_model.dart';

class ProfileNotifier extends StateNotifier<CaregiverProfileModel> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(_emptyProfile()) {
    _ref.listen(authStateProvider, (previous, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        refresh();
      } else {
        state = _emptyProfile();
      }
    });
    refresh();
  }

  DioClient get _dio => _ref.read(dioClientProvider);

  Future<void> refresh() async {
    final auth = _ref.read(authStateProvider).value;
    if (!(auth?.isAuthenticated ?? false)) {
      state = _emptyProfile();
      return;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiPaths.myCaregiverProfile,
      );
      state = _mapProfile(response.data ?? {}, authDisplayName: auth?.phone);
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileNotifier] Lỗi tải hồ sơ caregiver: $e');
    }
  }

  Future<void> updateProfile({
    required String name,
    required String experience,
    required String location,
    required double hourlyRate,
    required List<String> skills,
    required String certifications,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      ApiPaths.myCaregiverProfile,
      data: {
        'fullName': name,
        'yearsOfExperience': _parseYears(experience),
        'hourlyRateExpected': hourlyRate.round(),
        'skills': jsonEncode(skills),
        'serviceCity': _extractCity(location),
        'serviceDistrict': _extractDistrict(location),
      },
    );
    await refresh();
  }

  Future<void> toggleAvailability() async {
    final nextStatus = state.isAvailable ? 'OFFLINE' : 'ONLINE';
    try {
      await _dio.put<Map<String, dynamic>>(
        ApiPaths.myCaregiverStatus,
        data: {'status': nextStatus},
      );
      await refresh();
      return;
    } catch (e) {
      // ignore: avoid_print
      print('[ProfileNotifier] Lỗi cập nhật trạng thái: $e');
      return;
    }
  }

  CaregiverProfileModel _mapProfile(
    Map<String, dynamic> json, {
    String? authDisplayName,
  }) {
    final name = _string(json['fullName'] ?? json['FullName']) ??
        authDisplayName ??
        'Caregiver';
    final serviceCity = _string(json['serviceCity'] ?? json['ServiceCity']);
    final serviceDistrict =
        _string(json['serviceDistrict'] ?? json['ServiceDistrict']);
    final years = _int(json['yearsOfExperience'] ?? json['YearsOfExperience']);
    final status =
        (_string(json['availabilityStatus'] ?? json['AvailabilityStatus']) ??
                'OFFLINE')
            .toUpperCase();
    final hourlyRate =
        _num(json['hourlyRateExpected'] ?? json['HourlyRateExpected']);

    return CaregiverProfileModel(
      id: _string(json['id'] ?? json['Id']) ?? '',
      name: name,
      avatarInitial: _initials(name),
      rating: _num(json['ratingAvg'] ?? json['RatingAvg']),
      totalReviews: _int(json['ratingCount'] ?? json['RatingCount']) ?? 0,
      completedShifts: _int(
            json['completedShiftsCount'] ?? json['CompletedShiftsCount'],
          ) ??
          state.completedShifts,
      skills: _parseSkills(json['skills'] ?? json['Skills']),
      experience: years == null ? 'Chưa cập nhật' : '$years năm kinh nghiệm',
      location: _joinLocation(serviceDistrict, serviceCity),
      hourlyRate: hourlyRate,
      isAvailable: status == 'ONLINE',
      certifications: state.certifications,
    );
  }

  static CaregiverProfileModel _emptyProfile() {
    return const CaregiverProfileModel(
      id: '',
      name: 'Caregiver',
      avatarInitial: 'CG',
      rating: 0,
      totalReviews: 0,
      completedShifts: 0,
      skills: [],
      experience: 'Chưa cập nhật',
      location: 'Chưa cập nhật',
      hourlyRate: 0,
      isAvailable: false,
      certifications: '',
    );
  }

  static List<String> _parseSkills(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((item) => item.toString()).where(_notBlank).toList();
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).where(_notBlank).toList();
      }
    } catch (_) {
      // Fallback comma/semicolon parser below.
    }
    return text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where(_notBlank)
        .toList();
  }

  static bool _notBlank(String value) => value.trim().isNotEmpty;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where(_notBlank).toList();
    if (parts.isEmpty) return 'CG';
    if (parts.length == 1) {
      final first = parts.first;
      return first
          .substring(0, first.length < 2 ? first.length : 2)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static int? _parseYears(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static String? _extractCity(String location) {
    final parts =
        location.split(',').map((p) => p.trim()).where(_notBlank).toList();
    return parts.length >= 2 ? parts.last : null;
  }

  static String? _extractDistrict(String location) {
    final parts =
        location.split(',').map((p) => p.trim()).where(_notBlank).toList();
    return parts.isEmpty ? null : parts.first;
  }

  static String _joinLocation(String? district, String? city) {
    final parts =
        [district, city].whereType<String>().where(_notBlank).toList();
    return parts.isEmpty ? 'Chưa cập nhật' : parts.join(', ');
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, CaregiverProfileModel>((ref) {
  return ProfileNotifier(ref);
});
