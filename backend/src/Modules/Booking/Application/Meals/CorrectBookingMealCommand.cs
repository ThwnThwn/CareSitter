using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record CorrectBookingMealCommand(Guid BookingId, Guid RecordId,
    string Outcome, string? Note, string Reason, int ExpectedRevision, Guid IdempotencyKey)
    : IRequest<Result<BookingMealRecordResponse>>;
public sealed record BookingMealCorrectionResponse(Guid Id, int Revision, string Outcome,
    string? Note, string Reason, Guid CorrectedBy, DateTimeOffset CorrectedAt, Guid TimelineEventId);
