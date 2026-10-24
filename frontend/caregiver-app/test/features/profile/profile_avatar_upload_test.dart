import 'dart:typed_data';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/profile/data/repositories/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _RecordingClient implements DioClient {
  String? path;
  dynamic data;
  FormData? formData;

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    this.path = path;
    this.data = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> postForm<T>(String path, FormData data,
      {CancelToken? cancelToken}) async {
    this.path = path;
    formData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('profile update serializes skills as a JSON array', () async {
    final client = _RecordingClient();
    final repository = ProfileRepository(client);

    await repository.updateProfile(
      fullName: 'Nguyen Thi Bich Ngoc',
      skills: const ['cham soc tre em', 'nau an'],
    );

    expect(client.path, '/caregivers/me/profile');
    expect(client.data, {
      'fullName': 'Nguyen Thi Bich Ngoc',
      'skills': '["cham soc tre em","nau an"]',
    });
  });

  test('avatar upload sends browser XFile bytes with its MIME type', () async {
    final client = _RecordingClient();
    final repository = ProfileRepository(client);
    final image = XFile.fromData(
      Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
      name: 'avatar.png',
      mimeType: 'image/png',
    );

    expect(await repository.uploadAvatar(image), isTrue);

    expect(client.path, '/profile/avatar');
    final file = client.formData!.files.single;
    expect(file.key, 'file');
    expect(file.value.filename, 'avatar.png');
    expect(file.value.contentType.toString(), 'image/png');
    expect(file.value.length, 4);
  });
}
