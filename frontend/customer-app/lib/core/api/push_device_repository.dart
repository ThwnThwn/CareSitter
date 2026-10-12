import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_client.dart';

final pushDeviceRepositoryProvider =
    Provider((ref) => PushDeviceRepository(ref.read(dioClientProvider)));

class PushDeviceRepository {
  const PushDeviceRepository(this._client);
  final DioClient _client;
  Future<String?> register(
      {required String platform,
      required String pushToken,
      required String deviceName}) async {
    final response =
        await _client.post<Map<String, dynamic>>('/auth/devices', data: {
      'platform': platform,
      'pushToken': pushToken,
      'deviceName': deviceName,
    });
    return response.data?['id']?.toString();
  }

  Future<void> unregister(String id) =>
      _client.delete<void>('/auth/devices/$id');
}
