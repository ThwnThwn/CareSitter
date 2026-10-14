using global::Grpc.Core;
using global::Grpc.Core.Interceptors;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionRpcInterceptor(ILogger<NutritionRpcInterceptor> logger) : Interceptor
{
    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(TRequest request,
        ServerCallContext context, UnaryServerMethod<TRequest, TResponse> continuation)
    {
        try { return await continuation(request, context); }
        catch (RpcException) { throw; }
        catch (OperationCanceledException) when (context.CancellationToken.IsCancellationRequested)
        {
            throw new RpcException(new Status(StatusCode.Cancelled, "nutrition.cancelled"));
        }
        catch (Exception exception)
        {
            logger.LogWarning("Nutrition RPC failed ({ErrorType}), trace {TraceId}.",
                exception.GetType().Name, context.GetHttpContext().TraceIdentifier);
            throw new RpcException(new Status(StatusCode.Unavailable, "nutrition.service_unavailable"));
        }
    }
}
