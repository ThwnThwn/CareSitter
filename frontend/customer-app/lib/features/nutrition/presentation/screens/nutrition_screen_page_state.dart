import '../../data/models/health_profile_model.dart';
import '../models/nutrition_flow_model.dart';

class NutritionScreenPageState {
  const NutritionScreenPageState({
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.session,
    required this.flow,
    required this.health,
    required this.editing,
    required this.dirty,
    required this.selectedDate,
    required this.hasPlanForSelectedDate,
    required this.isLoadingSelectedDate,
    required this.dateError,
    required this.canReturnToMenu,
    required this.canReturnToBeneficiaries,
    required this.canEdit,
    required this.canOpenHistory,
    required this.canChangeBeneficiary,
  });

  final String beneficiaryId;
  final String? beneficiaryName;
  final int session;
  final NutritionFlow flow;
  final HealthProfileModel? health;
  final bool editing;
  final bool dirty;
  final DateTime selectedDate;
  final bool hasPlanForSelectedDate;
  final bool isLoadingSelectedDate;
  final String? dateError;
  final bool canReturnToMenu;
  final bool canReturnToBeneficiaries;
  final bool canEdit;
  final bool canOpenHistory;
  final bool canChangeBeneficiary;
}
