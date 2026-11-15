using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class CorrectBookingMealCommandHandler(IBookingMealStore store, ICurrentUser user,
    IPeopleLookupService people, IClock clock)
    : IRequestHandler<CorrectBookingMealCommand, Result<BookingMealRecordResponse>>
{
    public async Task<Result<BookingMealRecordResponse>> Handle(CorrectBookingMealCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } actor) return BookingErrors.Unauthenticated();
        if (request.IdempotencyKey == Guid.Empty || request.ExpectedRevision < 1 ||
            request.Outcome is not ("eaten" or "partly_eaten" or "not_eaten") || request.Note?.Length > 1000 ||
            string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 500)
            return Error.Validation("booking.meals.correction_request", "Vui lòng nhập kết quả và lý do đính chính hợp lệ.");
        return await store.InBookingScopeAsync<BookingMealRecordResponse>(request.BookingId, async (booking, session) =>
        {
            if (!user.IsInRole("CAREGIVER") || booking.CaregiverId is not { } caregiver ||
                !await people.IsCaregiverForBookingAsync(caregiver, actor, ct)) return BookingErrors.Forbidden();
            var record = (await session.RecordsAsync(ct)).SingleOrDefault(x => x.Id == request.RecordId);
            if (record is null || record.RecordedBy != actor) return BookingErrors.Forbidden();
            var history = await session.CorrectionsAsync(ct);
            var note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
            var reason = request.Reason.Trim();
            var replay = history.SingleOrDefault(x => x.IdempotencyKey == request.IdempotencyKey);
            if (replay is not null)
            {
                if (replay.RecordId != record.Id || replay.CorrectedBy != actor || replay.Outcome != request.Outcome ||
                    replay.Note != note || replay.Reason != reason || replay.Revision != request.ExpectedRevision + 1)
                    return Error.Conflict("booking.meals.idempotency_conflict", "Khóa đính chính đã được dùng cho nội dung khác.");
                return BookingMealRecordMapping.Map(record, history.Where(x => x.Revision <= replay.Revision));
            }
            if (!BookingMealPolicy.CanCorrect(booking.Status))
                return Error.Conflict("booking.meals.correction_closed", "Ca đã đóng. Vui lòng liên hệ hỗ trợ để đính chính.");
            var current = BookingMealRecordMapping.Map(record, history);
            if (current.Revision != request.ExpectedRevision)
                return Error.Conflict("booking.meals.revision_conflict", "Bữa ăn đã được đính chính ở nơi khác. Vui lòng tải lại.");
            var timeline = CareTimelineEvent.Create(booking.Id, caregiver, "NOTE", "Đính chính ghi nhận bữa ăn",
                $"Lý do: {reason}\nKết quả mới: {Label(request.Outcome)}{(note is null ? "" : $"\nLưu ý: {note}")}",
                metadata: JsonSerializer.Serialize(new { kind = "meal_correction", recordId = record.Id,
                    previousRevision = current.Revision, revision = current.Revision + 1 }));
            var correction = BookingMealCorrection.Create(booking.Id, record.Id, current.Revision + 1,
                request.Outcome, note, reason, actor, clock.UtcNow, request.IdempotencyKey, timeline.Id);
            session.Add(correction, timeline);
            return BookingMealRecordMapping.Map(record, history.Append(correction));
        }, ct);
    }
    private static string Label(string outcome) => outcome switch
        { "eaten" => "Đã ăn", "partly_eaten" => "Ăn một phần", _ => "Không ăn" };
}
