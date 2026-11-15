using CareSitter.Contracts.Nutrition;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record ShareBookingMealPlanCommand(Guid BookingId, Guid PlanId)
    : IRequest<Result<BookingMealPlanResponse>>;
public sealed record RevokeBookingMealPlanCommand(Guid BookingId, DateOnly PlannedDate)
    : IRequest<Result<bool>>;
public sealed record ListBookingMealsQuery(Guid BookingId) : IRequest<Result<BookingMealsResponse>>;
public sealed record RecordBookingMealCommand(Guid BookingId, Guid PlanId, Guid RecipeVersionId,
    string MealType, string Outcome, string? Note, Guid IdempotencyKey)
    : IRequest<Result<BookingMealRecordResponse>>;

public sealed record BookingMealPlanResponse(Guid PlanId, DateOnly PlannedDate,
    IReadOnlyList<SharedMeal> Meals, DateTimeOffset SharedAt, DateTimeOffset? RevokedAt,
    bool IsStale = false, string Status = "shared", bool CanRecord = false);
public sealed record BookingMealRecordResponse(Guid Id, Guid PlanId, DateOnly PlannedDate,
    Guid RecipeVersionId, string MealType, string Outcome, string? Note,
    Guid RecordedBy, DateTimeOffset RecordedAt, Guid TimelineEventId,
    int Revision = 1, IReadOnlyList<BookingMealCorrectionResponse>? Corrections = null,
    string? OriginalOutcome = null, string? OriginalNote = null, bool CanCorrect = false);

public sealed record BookingMealShareWindow(Guid BeneficiaryId, DateOnly FirstDate, DateOnly LastDate);

public sealed record BookingMealsResponse(IReadOnlyList<BookingMealPlanResponse> Plans,
    IReadOnlyList<BookingMealRecordResponse> Records, BookingMealShareWindow? ShareWindow = null);
