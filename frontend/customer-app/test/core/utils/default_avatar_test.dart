import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects an avatar from age group and normalized gender', () {
    expect(
      defaultAvatarAsset(age: 24, gender: 'Nữ'),
      'assets/images/default-avatar-young-female.png',
    );
    expect(
      defaultAvatarAsset(age: 45, gender: 'male'),
      'assets/images/default-avatar-middle-male.png',
    );
    expect(
      defaultAvatarAsset(age: 70, gender: 'female'),
      'assets/images/default-avatar-senior-female.png',
    );
  });

  test('derives age from date of birth without advancing before birthday', () {
    expect(
      defaultAvatarAsset(
        dateOfBirth: DateTime(1966, 12, 1),
        gender: 'nam',
        today: DateTime(2026, 10, 23),
      ),
      'assets/images/default-avatar-middle-male.png',
    );
  });

  test('uses a stable seed when gender is unavailable', () {
    expect(
      defaultAvatarAsset(age: 40, seed: 'A'),
      defaultAvatarAsset(age: 40, seed: 'A'),
    );
    expect(
      defaultAvatarAsset(age: 40, seed: 'A'),
      isNot(defaultAvatarAsset(age: 40, seed: 'B')),
    );
    expect(
      defaultAvatarAsset(seed: 'LV'),
      'assets/images/default-avatar-middle-male.png',
    );
  });

  test('parses profile dates used to select an age group', () {
    expect(parseAvatarDate('1966-12-01'), DateTime(1966, 12, 1));
    expect(parseAvatarDate('01/12/1966'), DateTime(1966, 12, 1));
    expect(parseAvatarDate(''), isNull);
    expect(parseAvatarDate('invalid'), isNull);
  });

  test('strict gender selection never guesses from a name', () {
    expect(
      defaultAvatarAssetForGender(age: 67, gender: 'FEMALE'),
      'assets/images/default-avatar-senior-female.png',
    );
    expect(
      defaultAvatarAssetForGender(age: 67, gender: 'UNSPECIFIED'),
      isNull,
    );
  });
}
