import 'dart:typed_data';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _RecordingClient implements DioClient {
  String? path;
  FormData? formData;

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
  test('check-in selfie sends browser XFile bytes with its MIME type',
      () async {
    final client = _RecordingClient();
    final repository = ShiftRepository(client);
    final image = XFile.fromData(
      Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]),
      name: 'selfie.png',
      mimeType: 'image/png',
    );

    await repository.uploadCheckInSelfie('booking-id', image);

    expect(client.path, '/bookings/booking-id/check-in/selfie');
    final file = client.formData!.files.single;
    expect(file.key, 'file');
    expect(file.value.filename, 'selfie.png');
    expect(file.value.contentType.toString(), 'image/png');
    expect(file.value.length, 4);
  });
}
