using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record BookingListResponse(
    IReadOnlyList<BookingResponse> Items, int Total, int Page, int PageSize,
    long SyncCursor = 0);
