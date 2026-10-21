using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Booking.Controllers;
using Microsoft.AspNetCore.Mvc;
using System.Reflection;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingCreationIdempotencyTests
{
    [Fact]
    public void Fingerprint_is_stable_for_equivalent_payloads()
    {
        var start = new DateTimeOffset(2026, 10, 22, 8, 0, 0, TimeSpan.FromHours(7));
        var first = Command(start, ["  feeding ", "mobility", "feeding"], " promo10 ");
        var second = Command(start.ToUniversalTime(), ["MOBILITY", "FEEDING"], "PROMO10");

        Assert.Equal(
            BookingCreationFingerprint.Compute(first),
            BookingCreationFingerprint.Compute(second));
    }

    [Fact]
    public void Fingerprint_changes_when_business_payload_changes()
    {
        var start = new DateTimeOffset(2026, 10, 22, 8, 0, 0, TimeSpan.FromHours(7));

        Assert.NotEqual(
            BookingCreationFingerprint.Compute(Command(start, ["feeding"], null)),
            BookingCreationFingerprint.Compute(Command(start.AddMinutes(30), ["feeding"], null)));
    }

    [Fact]
    public void Create_endpoint_reads_idempotency_key_from_header()
    {
        var method = typeof(BookingsController).GetMethod(nameof(BookingsController.Create));
        var parameter = Assert.Single(method!.GetParameters(), parameter =>
            parameter.GetCustomAttribute<FromHeaderAttribute>() is not null);
        var attribute = parameter.GetCustomAttribute<FromHeaderAttribute>();

        Assert.Equal("Idempotency-Key", attribute!.Name);
    }

    private static CreateBookingCommand Command(
        DateTimeOffset start,
        IReadOnlyList<string> skills,
        string? promotionCode) =>
        new(Guid.Parse("11111111-1111-1111-1111-111111111111"),
            Guid.Parse("22222222-2222-2222-2222-222222222222"),
            Guid.Parse("33333333-3333-3333-3333-333333333333"),
            start,
            start.AddHours(2),
            RequiredSkills: skills,
            PromotionCode: promotionCode,
            IdempotencyKey: Guid.Parse("44444444-4444-4444-4444-444444444444"));
}
