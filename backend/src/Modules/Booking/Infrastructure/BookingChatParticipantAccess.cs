using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatParticipantAccess(ICurrentUser currentUser, IPeopleLookupService people)
{
    public async Task<string?> ResolveRoleAsync(
        Domain.Booking booking, Guid userId, CancellationToken ct)
    {
        if (booking.CustomerId == userId && currentUser.IsInRole("CUSTOMER"))
            return "CUSTOMER";
        if (!currentUser.IsInRole("CAREGIVER") || booking.CaregiverId is not { } caregiverId)
            return null;
        return await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)
            ? "CAREGIVER"
            : null;
    }
}
