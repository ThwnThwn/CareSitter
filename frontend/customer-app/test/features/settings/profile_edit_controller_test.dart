import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_edit_controller.dart';

void main() {
  test('disposing during avatar upload prevents a follow-up profile write',
      () async {
    final upload = Completer<bool>();
    final started = Completer<void>();
    var updates = 0;
    final controller = ProfileEditController(
      uploadAvatar: (_, name) {
        started.complete();
        return upload.future;
      },
      updateProfile: (
          {required name,
          required displayName,
          required email,
          required dob,
          required gender}) async {
        updates++;
        return true;
      },
    );
    final pending = controller.save(
        name: 'A',
        displayName: 'A',
        email: 'a@example.com',
        dob: '',
        gender: 'OTHER',
        avatar: XFile.fromData(Uint8List.fromList([1, 2]), name: 'avatar.png'));
    await started.future;
    controller.dispose();
    upload.complete(true);
    expect((await pending).ignored, isTrue);
    expect(updates, 0);
  });

  test('failed avatar stays recoverable while the other profile fields save',
      () async {
    final controller = ProfileEditController(
      uploadAvatar: (_, name) async => false,
      updateProfile: (
              {required name,
              required displayName,
              required email,
              required dob,
              required gender}) async =>
          true,
    );
    addTearDown(controller.dispose);
    final result = await controller.save(
        name: 'A',
        displayName: 'A',
        email: 'a@example.com',
        dob: '',
        gender: 'OTHER',
        avatar: XFile.fromData(Uint8List.fromList([1, 2]), name: 'avatar.png'));
    expect(result.saved, isTrue);
    expect(result.avatarUploaded, isFalse);
    expect(result.message, contains('giữ để thử lại'));
  });

  test('concurrent submits do not write profile twice', () async {
    final update = Completer<bool>();
    var writes = 0;
    final controller = ProfileEditController(
      uploadAvatar: (_, name) async => true,
      updateProfile: (
          {required name,
          required displayName,
          required email,
          required dob,
          required gender}) {
        writes++;
        return update.future;
      },
    );
    addTearDown(controller.dispose);
    final first = controller.save(
        name: 'A',
        displayName: 'A',
        email: 'a@example.com',
        dob: '',
        gender: 'OTHER');
    final repeat = await controller.save(
        name: 'A',
        displayName: 'A',
        email: 'a@example.com',
        dob: '',
        gender: 'OTHER');
    expect(repeat.ignored, isTrue);
    expect(writes, 1);
    update.complete(true);
    expect((await first).saved, isTrue);
  });
}
