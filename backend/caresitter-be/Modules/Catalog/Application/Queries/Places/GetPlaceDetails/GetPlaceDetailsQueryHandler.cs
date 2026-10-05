using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

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
