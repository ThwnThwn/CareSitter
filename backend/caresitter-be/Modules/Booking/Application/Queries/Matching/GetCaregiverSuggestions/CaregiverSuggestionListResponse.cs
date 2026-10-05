using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record CaregiverSuggestionListResponse(
    IReadOnlyList<CaregiverSuggestionResponse> Items, int Total);
