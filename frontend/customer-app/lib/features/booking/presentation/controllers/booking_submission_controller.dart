import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../../beneficiary/data/models/beneficiary_model.dart';
import '../../data/models/booking_draft.dart';
import '../../domain/schedule_rules.dart';
import '../../domain/booking_error_codes.dart';
import 'booking_created_exception.dart';
import 'booking_outcome_unknown.dart';
import 'booking_submission_actions.dart';
import 'booking_submission_outcome.dart';
import 'booking_submit_result.dart';
import 'booking_wizard_state.dart';

/// Use case xác nhận cuối; chỉ giữ khóa của thao tác, không giữ entity trong flow.
class BookingSubmissionController {
  BookingSubmissionController(this.actions);
  final BookingSubmissionActions actions;
  final Map<String, String> _keys = {};
  Future<BookingSubmissionOutcome> submit(BookingWizardState snapshot,
      {required BeneficiaryModel recipient,
      required String serviceId,
      required String? caregiverId,
      required bool Function() current,
      required void Function(String) progress}) async {
    BookingDraft? draft;
    try {
      if (!current()) return _outcome(const BookingSubmitIgnored());
      if (snapshot.forSelf) {
        progress('Đang lưu thông tin chăm sóc…');
        final resolved = await actions.resolveSelf(snapshot.addressId!);
        if (!current()) return _outcome(const BookingSubmitIgnored());
        recipient = resolved.profile;
        actions.publishSelf(recipient);
        if (resolved.needsReview || !actions.selfComplete) {
          return _outcome(
              const BookingSubmitMessage(
                  'Hồ sơ đã được cập nhật. Vui lòng kiểm tra lại trước khi đặt lịch.'),
              reviewRecipient: true);
        }
      }
      if (!current()) return _outcome(const BookingSubmitIgnored());
      progress('Đang đặt lịch…');
      final start = ScheduleRules.at(snapshot.date!, snapshot.startMinutes!);
      final key = _keys.putIfAbsent(
          jsonEncode([
            recipient.id,
            serviceId,
            snapshot.addressId,
            start.toUtc().toIso8601String(),
            snapshot.duration
          ]),
          () => const Uuid().v4());
      draft = BookingDraft(
          idempotencyKey: key,
          beneficiaryId: recipient.id,
          serviceTypeId: serviceId,
          caregiverId: caregiverId,
          isSystemMatched: snapshot.systemMatched,
          addressId: snapshot.addressId!,
          scheduledStart: start,
          scheduledEnd: start.add(Duration(hours: snapshot.duration)));
      final booking = await actions.createBooking(draft);
      return _outcome(current()
          ? BookingSubmitted(
              booking.id, 'Đã tạo booking • đang chờ caregiver nhận ca')
          : const BookingSubmitIgnored());
    } on BookingCreatedException catch (error) {
      return _outcome(current()
          ? BookingSubmitted(error.booking.id,
              'Lịch đã được tạo. Chưa xác nhận được người chăm sóc; hãy kiểm tra trên lịch này.')
          : const BookingSubmitIgnored());
    } on BookingOutcomeUnknown {
      return _outcome(const BookingSubmitIgnored(),
          uncertainDraft: current() ? draft : null);
    } on AppApiException catch (error) {
      if (!current()) return _outcome(const BookingSubmitIgnored());
      final conflict =
          BookingErrorCodes.caregiverConflicts.contains(error.code);
      return _outcome(
          BookingSubmitMessage(
              conflict
                  ? 'Chăm sóc viên đã có lịch trong khung giờ này. Vui lòng chọn chăm sóc viên khác hoặc đổi giờ.'
                  : error.message,
              caregiverConflict: conflict),
          reviewRecipient: error.code?.startsWith('beneficiary.') == true,
          reloadSelf: error.code == BookingErrorCodes.selfExists);
    } catch (_) {
      return _outcome(current()
          ? const BookingSubmitMessage(
              'Chưa hoàn tất đặt lịch. Vui lòng kiểm tra thông tin và thử lại.')
          : const BookingSubmitIgnored());
    }
  }

  BookingSubmissionOutcome _outcome(BookingSubmitResult result,
          {BookingDraft? uncertainDraft,
          bool reviewRecipient = false,
          bool reloadSelf = false}) =>
      (
        result: result,
        uncertainDraft: uncertainDraft,
        reviewRecipient: reviewRecipient,
        reloadSelf: reloadSelf
      );
}
