using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record GetPlaceDetailsQuery(string PlaceId, string? SessionToken)
    : IRequest<Result<VerifiedPlaceDetails>>;
