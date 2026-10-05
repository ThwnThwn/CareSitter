using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record AutocompletePlacesQuery(string Input, string? SessionToken)
    : IRequest<Result<IReadOnlyList<PlaceSuggestion>>>;
