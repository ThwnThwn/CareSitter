using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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
