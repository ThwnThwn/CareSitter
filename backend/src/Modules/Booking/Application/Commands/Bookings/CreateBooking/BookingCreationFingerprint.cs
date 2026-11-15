using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

internal static class BookingCreationFingerprint
{
    public static string Compute(CreateBookingCommand command)
    {
        var canonical = new
        {
            command.BeneficiaryId,
            command.AddressId,
            command.ServiceTypeId,
            ScheduledStartUtcTicks = command.ScheduledStart.UtcTicks,
            ScheduledEndUtcTicks = command.ScheduledEnd.UtcTicks,
            command.CaregiverId,
            RequiredSkills = (command.RequiredSkills ?? [])
                .Select(skill => skill.Trim().ToUpperInvariant())
                .Where(skill => skill.Length > 0)
                .Distinct(StringComparer.Ordinal)
                .Order(StringComparer.Ordinal)
                .ToArray(),
            PromotionCode = command.PromotionCode?.Trim().ToUpperInvariant()
        };
        var payload = JsonSerializer.Serialize(canonical);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload)))
            .ToLowerInvariant();
    }
}
