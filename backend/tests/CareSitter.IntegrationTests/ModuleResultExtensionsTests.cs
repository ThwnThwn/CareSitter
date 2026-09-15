using System.Text.Json;
using CareSitter.Modules.Catalog.Controllers;
using CareSitter.Modules.People.Controllers;
using CareSitter.Modules.Support.Controllers;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.IntegrationTests;

public sealed class ModuleResultExtensionsTests
{
    private readonly TestController _controller = new();

    [Fact]
    public void Catalog_place_failure_keeps_503_anonymous_body()
    {
        var failure = Result.Failure<object>(Error.Unavailable(
            "catalog.place_service.unavailable", "Geoapify unavailable"));

        var result = Assert.IsType<ObjectResult>(
            CatalogResultExtensions.ToActionResult(failure, _controller));

        Assert.Equal(StatusCodes.Status503ServiceUnavailable, result.StatusCode);
        AssertAnonymousError(result.Value, "Geoapify unavailable");
    }

    [Fact]
    public void Catalog_address_delete_keeps_409_anonymous_body()
    {
        var failure = Result.Failure<object>(Error.Conflict(
            "catalog.address.in_use", "Dia chi dang duoc su dung va không thể xoa."));

        var result = Assert.IsType<ConflictObjectResult>(
            CatalogResultExtensions.ToActionResult(failure, _controller));

        AssertAnonymousError(result.Value, "Dia chi dang duoc su dung va không thể xoa.");
    }

    [Fact]
    public void People_missing_caregiver_profile_keeps_404_anonymous_body()
    {
        var failure = Result.Failure<object>(Error.NotFound(
            "people.caregiver_profile.not_found", "Caregiver profile khong ton tai."));

        var result = Assert.IsType<NotFoundObjectResult>(
            PeopleResultExtensions.ToActionResult(failure, _controller));

        AssertAnonymousError(result.Value, "Caregiver profile khong ton tai.");
    }

    [Fact]
    public void People_kyc_shape_error_keeps_400_anonymous_body()
    {
        var failure = Result.Failure<object>(Error.Validation(
            "people.kyc.invalid_cccd", "So CCCD phai gom 9 hoac 12 chu so."));

        var result = Assert.IsType<BadRequestObjectResult>(
            PeopleResultExtensions.ToActionResult(failure, _controller));

        AssertAnonymousError(result.Value, "So CCCD phai gom 9 hoac 12 chu so.");
    }

    [Fact]
    public void Support_review_precheck_keeps_unaccented_duplicate_message()
    {
        var failure = Result.Failure<object>(Error.Conflict(
            "support.review.already_exists", "Booking nay da co review."));

        var result = Assert.IsType<ConflictObjectResult>(
            SupportResultExtensions.ToActionResult(failure, _controller));

        AssertAnonymousError(result.Value, "Booking nay da co review.");
    }

    [Fact]
    public void Support_review_race_keeps_accented_duplicate_message()
    {
        var failure = Result.Failure<object>(Error.Conflict(
            "support.review.concurrent_duplicate", "Booking này đã có review."));

        var result = Assert.IsType<ConflictObjectResult>(
            SupportResultExtensions.ToActionResult(failure, _controller));

        AssertAnonymousError(result.Value, "Booking này đã có review.");
    }

    private static void AssertAnonymousError(object? value, string expected)
    {
        var body = JsonSerializer.SerializeToElement(value);
        Assert.Equal(expected, body.GetProperty("error").GetString());
        Assert.Single(body.EnumerateObject());
    }

    private sealed class TestController : ControllerBase;
}
