import '../../data/models/booking_draft.dart';
import 'booking_submit_result.dart';

typedef BookingSubmissionOutcome = ({
  BookingSubmitResult result,
  BookingDraft? uncertainDraft,
  bool reviewRecipient,
  bool reloadSelf
});
