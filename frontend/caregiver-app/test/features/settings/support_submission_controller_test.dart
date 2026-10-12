import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:caregiver_app/features/settings/presentation/controllers/support_submission_controller.dart';

class _Actions implements SettingsController {
  final pending = Completer<String>();
  ApiCancellation? cancellation;
  int uploads = 0, tickets = 0;
  @override
  Future<String> uploadSupportAttachment(XFile file,
      {ApiCancellation? cancellation}) {
    uploads++;
    this.cancellation = cancellation;
    return pending.future;
  }

  @override
  Future<String?> createSupportTicket(
      {required String title,
      required String description,
      required List<String> attachmentUrls,
      ApiCancellation? cancellation}) async {
    tickets++;
    return 'ticket';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('disposal cancels upload and prevents subsequent ticket creation',
      () async {
    final actions = _Actions();
    final controller = SupportSubmissionController(actions);
    final result =
        controller.submit('title', 'description', [XFile('attachment')]);
    controller.dispose();
    expect(actions.cancellation!.isCancelled, isTrue);
    actions.pending.complete('uploaded');
    expect(await result, isA<SupportIgnored>());
    expect(actions.tickets, 0);
  });
  test('submission snapshots attachments and blocks a second request',
      () async {
    final actions = _Actions();
    final controller = SupportSubmissionController(actions);
    addTearDown(controller.dispose);
    final files = [XFile('attachment')];
    final first = controller.submit('title', 'description', files);
    files.add(XFile('later-attachment'));
    expect(await controller.submit('title', 'description', files),
        isA<SupportIgnored>());
    actions.pending.complete('uploaded');
    expect(await first, isA<SupportSubmitted>());
    expect(actions.uploads, 1);
    expect(actions.tickets, 1);
  });
}
