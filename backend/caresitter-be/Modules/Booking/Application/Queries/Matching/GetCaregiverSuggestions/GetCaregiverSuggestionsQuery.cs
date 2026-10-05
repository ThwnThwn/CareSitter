using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record GetCaregiverSuggestionsQuery(Guid BookingId, int Limit = 10)
    : IRequest<Result<CaregiverSuggestionListResponse>>;
