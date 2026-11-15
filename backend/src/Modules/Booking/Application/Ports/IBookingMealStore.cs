using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingMealStore
{
    Task<Result<T>> InBookingScopeAsync<T>(Guid bookingId,
        Func<Domain.Booking, IBookingMealSession, Task<Result<T>>> action, CancellationToken ct);
}

internal interface IBookingMealSession
{
    Task<IReadOnlyList<BookingMealPlan>> PlansAsync(CancellationToken ct);
    Task<IReadOnlyList<BookingMealRecord>> RecordsAsync(CancellationToken ct);
    Task<IReadOnlyList<BookingMealCorrection>> CorrectionsAsync(CancellationToken ct);
    void Add(BookingMealPlan plan);
    void Add(BookingMealRecord record, CareTimelineEvent timelineEvent);
    void Add(BookingMealCorrection correction, CareTimelineEvent timelineEvent);
}
