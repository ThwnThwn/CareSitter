using CareSitter.Contracts.Services.Routing;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.ApiHost.Routing;

public sealed class RoutingExceptionHandler(
    ILogger<RoutingExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not RoutingException routingException)
            return false;

        var statusCode = routingException switch
        {
            RoutingInvalidLocationException => StatusCodes.Status400BadRequest,
            RoutingLimitExceededException => StatusCodes.Status503ServiceUnavailable,
            RoutingProviderUnavailableException => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status500InternalServerError
        };

        logger.LogWarning(exception,
            "Routing request failed with {ErrorCode}.", routingException.ErrorCode);

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = routingException.ErrorCode,
            Detail = routingException.Message
        }, cancellationToken);

        return true;
    }
}
