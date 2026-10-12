import 'dart:async';
import '../../data/models/nutrition_resource_model.dart';
import '../../domain/nutrition_assessment_rules.dart';

class NutritionAssessmentPoller {
  Timer? _timer;
  int _generation = 0;
  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  void start(
      {required bool Function() active,
      required Future<NutritionResourceModel> Function() read,
      required void Function(NutritionResourceModel) publish,
      required void Function(NutritionResourceModel) timedOut,
      required void Function(Object) failed}) {
    stop();
    final generation = _generation;
    bool current() => generation == _generation && active();
    void schedule(int attempt) {
      _timer = Timer(NutritionAssessmentRules.pollDelay(attempt), () async {
        if (!current()) return;
        try {
          final resource = await read();
          if (!current()) return;
          publish(resource);
          if (NutritionAssessmentRules.pending(resource.status)) {
            if (attempt < NutritionAssessmentRules.maximumPollAttempt) {
              schedule(attempt + 1);
            } else {
              timedOut(resource);
            }
          }
        } catch (error) {
          if (current()) failed(error);
        }
      });
    }

    schedule(0);
  }
}
