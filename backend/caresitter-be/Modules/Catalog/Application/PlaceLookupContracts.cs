using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record AutocompletePlacesQuery(string Input, string? SessionToken)
    : IRequest<Result<IReadOnlyList<PlaceSuggestion>>>;
public sealed record GetPlaceDetailsQuery(string PlaceId, string? SessionToken)
    : IRequest<Result<VerifiedPlaceDetails>>;

internal sealed class AutocompletePlacesQueryHandler(
    ICurrentUser currentUser,
    IPlaceAutocompleteService places)
    : IRequestHandler<AutocompletePlacesQuery, Result<IReadOnlyList<PlaceSuggestion>>>
{
    public async Task<Result<IReadOnlyList<PlaceSuggestion>>> Handle(
        AutocompletePlacesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is null) return CatalogErrors.Unauthenticated();
        try
        {
            return Result.Success<IReadOnlyList<PlaceSuggestion>>(
                await places.AutocompleteAsync(request.Input, request.SessionToken, ct));
        }
        catch (InvalidOperationException ex)
        {
            return CatalogErrors.PlaceServiceUnavailable(ex.Message);
        }
    }
}

internal sealed class GetPlaceDetailsQueryHandler(
    ICurrentUser currentUser,
    IPlaceAutocompleteService places)
    : IRequestHandler<GetPlaceDetailsQuery, Result<VerifiedPlaceDetails>>
{
    public async Task<Result<VerifiedPlaceDetails>> Handle(
        GetPlaceDetailsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is null) return CatalogErrors.Unauthenticated();
        try
        {
            var details = await places.GetDetailsAsync(
                request.PlaceId, request.SessionToken, ct);
            return details is null ? CatalogErrors.PlaceNotFound() : details;
        }
        catch (InvalidOperationException ex)
        {
            return CatalogErrors.PlaceServiceUnavailable(ex.Message);
        }
    }
}
