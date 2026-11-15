using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingMealRecordMapping
{
    internal static BookingMealRecordResponse Map(BookingMealRecord record, IEnumerable<BookingMealCorrection>? history = null)
    {
        var corrections = (history ?? []).Where(x => x.RecordId == record.Id).OrderBy(x => x.Revision).ToArray();
        var latest = corrections.LastOrDefault();
        return new(record.Id, record.PlanId, record.PlannedDate, record.RecipeVersionId, record.MealType,
            latest?.Outcome ?? record.Outcome, latest is null ? record.Note : latest.Note,
            record.RecordedBy, record.RecordedAt, record.TimelineEventId, latest?.Revision ?? 1,
            corrections.Select(x => new BookingMealCorrectionResponse(x.Id, x.Revision, x.Outcome,
                x.Note, x.Reason, x.CorrectedBy, x.CorrectedAt, x.TimelineEventId)).ToArray(),
            record.Outcome, record.Note);
    }
}
