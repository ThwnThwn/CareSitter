namespace CareSitter.Contracts.Services;

public interface IBookingReportAccess
{
    Task<bool> IsCustomerAsync(Guid bookingId, Guid userId, CancellationToken ct = default);
}
