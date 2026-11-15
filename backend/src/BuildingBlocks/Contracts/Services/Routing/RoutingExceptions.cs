namespace CareSitter.Contracts.Services.Routing;

public abstract class RoutingException : Exception
{
    protected RoutingException(string errorCode, string message, Exception? innerException = null)
        : base(message, innerException)
    {
        ErrorCode = errorCode;
    }

    public string ErrorCode { get; }
}

public sealed class RoutingLimitExceededException : RoutingException
{
    public RoutingLimitExceededException(string message = "Routing provider quota exceeded.")
        : base("ROUTING_LIMIT_EXCEEDED", message)
    {
    }
}

public sealed class RoutingProviderUnavailableException : RoutingException
{
    public RoutingProviderUnavailableException(string message = "Routing provider unavailable.", Exception? innerException = null)
        : base("ROUTING_PROVIDER_UNAVAILABLE", message, innerException)
    {
    }
}

public sealed class RoutingInvalidLocationException : RoutingException
{
    public RoutingInvalidLocationException(string message = "Routing request contains invalid coordinates.")
        : base("ROUTING_INVALID_LOCATION", message)
    {
    }
}
