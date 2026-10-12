const _absent = Object();

class BeneficiaryFormState {
  const BeneficiaryFormState(
      {this.addressId,
      this.gender,
      this.relation = 'Bố',
      this.careLevel = 'Nhẹ',
      this.avatarPath,
      this.conditions = const [],
      this.isSelf = false,
      this.profileFound = false,
      this.saving = false});
  final String? addressId, gender, avatarPath;
  final String relation, careLevel;
  final List<String> conditions;
  final bool isSelf, profileFound, saving;
  BeneficiaryFormState copy(
          {Object? addressId = _absent,
          Object? gender = _absent,
          Object? avatarPath = _absent,
          String? relation,
          String? careLevel,
          List<String>? conditions,
          bool? isSelf,
          bool? profileFound,
          bool? saving}) =>
      BeneficiaryFormState(
          addressId: identical(addressId, _absent)
              ? this.addressId
              : addressId as String?,
          gender: identical(gender, _absent) ? this.gender : gender as String?,
          avatarPath: identical(avatarPath, _absent)
              ? this.avatarPath
              : avatarPath as String?,
          relation: relation ?? this.relation,
          careLevel: careLevel ?? this.careLevel,
          conditions: List.unmodifiable(conditions ?? this.conditions),
          isSelf: isSelf ?? this.isSelf,
          profileFound: profileFound ?? this.profileFound,
          saving: saving ?? this.saving);
}
