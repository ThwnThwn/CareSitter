enum DefaultAvatarAgeGroup { young, middle, senior }

String defaultAvatarAsset({
  int? age,
  DateTime? dateOfBirth,
  String? gender,
  String seed = '',
  DateTime? today,
}) {
  final resolvedAge = age ?? _ageAt(dateOfBirth, today ?? DateTime.now());
  final isFemale = _explicitIsFemale(gender) ??
      seed.codeUnits.fold<int>(0, (sum, value) => sum + value).isOdd;
  return _avatarAsset(resolvedAge, isFemale: isFemale);
}

String? defaultAvatarAssetForGender({
  int? age,
  DateTime? dateOfBirth,
  String? gender,
  DateTime? today,
}) {
  final isFemale = _explicitIsFemale(gender);
  if (isFemale == null) return null;
  final resolvedAge = age ?? _ageAt(dateOfBirth, today ?? DateTime.now());
  return _avatarAsset(resolvedAge, isFemale: isFemale);
}

String _avatarAsset(int? resolvedAge, {required bool isFemale}) {
  final ageGroup = resolvedAge == null
      ? DefaultAvatarAgeGroup.middle
      : resolvedAge < 35
          ? DefaultAvatarAgeGroup.young
          : resolvedAge >= 60
              ? DefaultAvatarAgeGroup.senior
              : DefaultAvatarAgeGroup.middle;
  final ageName = switch (ageGroup) {
    DefaultAvatarAgeGroup.young => 'young',
    DefaultAvatarAgeGroup.middle => 'middle',
    DefaultAvatarAgeGroup.senior => 'senior',
  };
  return 'assets/images/default-avatar-$ageName-${isFemale ? 'female' : 'male'}.png';
}

int? _ageAt(DateTime? dateOfBirth, DateTime today) {
  if (dateOfBirth == null) return null;
  var value = today.year - dateOfBirth.year;
  if (today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
    value--;
  }
  return value;
}

bool? _explicitIsFemale(String? gender) {
  final normalized = gender?.trim().toLowerCase() ?? '';
  if (normalized == 'female' ||
      normalized == 'f' ||
      normalized == 'nữ' ||
      normalized == 'nu') {
    return true;
  }
  if (normalized == 'male' || normalized == 'm' || normalized == 'nam') {
    return false;
  }
  return null;
}
