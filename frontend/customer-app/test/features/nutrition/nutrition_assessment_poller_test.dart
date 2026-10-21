import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/domain/nutrition_assessment_rules.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_assessment_poller.dart';

void main() {
  test('scheduled polling delay stays below one minute', () {
    var total = Duration.zero;
    for (var attempt = 0;
        attempt <= NutritionAssessmentRules.maximumPollAttempt;
        attempt++) {
      total += NutritionAssessmentRules.pollDelay(attempt);
    }

    expect(total, const Duration(seconds: 46));
    expect(total < const Duration(minutes: 1), isTrue);
  });

  testWidgets(
      'stopping a poll ignores its late response and cancels the next tick',
      (tester) async {
    final poller = NutritionAssessmentPoller();
    final pending = Completer<NutritionResourceModel>();
    var reads = 0, published = 0;
    poller.start(
        active: () => true,
        read: () {
          reads++;
          return pending.future;
        },
        publish: (_) => published++,
        timedOut: (_) => fail('unexpected timeout'),
        failed: (_) => fail('unexpected failure'));
    await tester.pump(const Duration(seconds: 2));
    expect(reads, 1);
    poller.stop();
    pending.complete(_resource('processing'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(published, 0);
    expect(reads, 1);
  });
  testWidgets('a terminal result stops polling after a processing result',
      (tester) async {
    final poller = NutritionAssessmentPoller();
    var reads = 0;
    final statuses = <String>[];
    poller.start(
        active: () => true,
        read: () async =>
            _resource(++reads == 1 ? 'processing' : 'awaiting_confirmation'),
        publish: (resource) => statuses.add(resource.status),
        timedOut: (_) => fail('unexpected timeout'),
        failed: (_) => fail('unexpected failure'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 10));
    expect(statuses, ['processing', 'awaiting_confirmation']);
    expect(reads, 2);
    poller.stop();
  });
}

NutritionResourceModel _resource(String status) =>
    NutritionResourceModel.fromJson({'id': 'assessment', 'status': status});
