import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/mock/mock_data.dart';

class ProfileNotifier extends StateNotifier<MockCaregiver> {
  ProfileNotifier()
      : super(
          const MockCaregiver(
            id: 'cg_01',
            name: MockData.currentUserName,
            avatarInitial: MockData.currentUserAvatar,
            rating: 4.9,
            totalReviews: 23,
            completedShifts: 48,
            skills: ['Chăm sóc người già', 'Hỗ trợ ăn uống', 'Đo huyết áp', 'Sơ cứu cơ bản'],
            experience: '5 năm kinh nghiệm',
            location: 'Quận 5, TP.HCM',
            hourlyRate: 85000,
            isAvailable: true,
            certifications: 'Chứng chỉ Điều dưỡng sơ cấp, Chứng chỉ Sơ cấp cứu Red Cross',
          ),
        );

  void updateProfile({
    required String name,
    required String experience,
    required String location,
    required double hourlyRate,
    required List<String> skills,
    required String certifications,
  }) {
    state = MockCaregiver(
      id: state.id,
      name: name,
      avatarInitial: name.isNotEmpty ? name.split(' ').last.substring(0, 1).toUpperCase() : 'CG',
      rating: state.rating,
      totalReviews: state.totalReviews,
      completedShifts: state.completedShifts,
      skills: skills,
      experience: experience,
      location: location,
      hourlyRate: hourlyRate,
      isAvailable: state.isAvailable,
      certifications: certifications,
    );
  }

  void toggleAvailability() {
    state = MockCaregiver(
      id: state.id,
      name: state.name,
      avatarInitial: state.avatarInitial,
      rating: state.rating,
      totalReviews: state.totalReviews,
      completedShifts: state.completedShifts,
      skills: state.skills,
      experience: state.experience,
      location: state.location,
      hourlyRate: state.hourlyRate,
      isAvailable: !state.isAvailable,
      certifications: state.certifications,
    );
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, MockCaregiver>((ref) {
  return ProfileNotifier();
});
