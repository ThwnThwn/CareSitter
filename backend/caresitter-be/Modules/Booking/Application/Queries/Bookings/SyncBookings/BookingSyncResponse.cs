using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record BookingSyncResponse(
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    IReadOnlyList<BookingResponse>? Items,
    long NextCursor,
    DateTimeOffset ServerTime,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    bool? HasMore,
    bool ResetRequired);
