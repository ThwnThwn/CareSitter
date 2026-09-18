class UserProfile {
  final String name;
  final String displayName;
  final String phone;
  final String email;
  final String dob;
  final String gender;
  final String? avatarUrl;
  final String? defaultAddressId;

  const UserProfile({
    required this.name,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.dob,
    required this.gender,
    this.avatarUrl,
    this.defaultAddressId,
  });

  UserProfile copyWith({
    String? name,
    String? displayName,
    String? phone,
    String? email,
    String? dob,
    String? gender,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? defaultAddressId,
    bool clearDefaultAddressId = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      defaultAddressId: clearDefaultAddressId
          ? null
          : (defaultAddressId ?? this.defaultAddressId),
    );
  }
}
