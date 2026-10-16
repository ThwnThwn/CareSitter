using System.Text.Json;
using CareSitter.Nutrition.Grpc.V1;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Grpc.Net.Client;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Nutrition;

internal sealed class NutritionGrpcGateway : INutritionGateway, IDisposable
{
    private const int MaxResponseBytes = 1024 * 1024;
    private readonly NutritionGatewayOptions _options;
    private readonly IHttpContextAccessor _context;
    private readonly ILogger<NutritionGrpcGateway> _logger;
    private readonly GrpcChannel? _channel;
    private readonly NutritionRpc.NutritionRpcClient? _client;

    public NutritionGrpcGateway(IOptions<NutritionGatewayOptions> options, IHttpContextAccessor context,
        ILogger<NutritionGrpcGateway> logger)
    {
        _options = options.Value; _context = context; _logger = logger;
        if (_options.Enabled)
        {
            _channel = GrpcChannel.ForAddress(_options.GrpcUrl, new GrpcChannelOptions
            {
                MaxReceiveMessageSize = MaxResponseBytes, MaxSendMessageSize = 32768,
                HttpHandler = InternalCertificateTrust.CreateHandler(_options.TrustedRootCertificatePath),
                DisposeHttpClient = true
            });
            _client = new NutritionRpc.NutritionRpcClient(_channel);
        }
    }

    public Task<NutritionGatewayResponse> CapabilitiesAsync(CancellationToken ct) => !_options.Enabled
        ? Task.FromResult(new NutritionGatewayResponse(200, new { enabled = false, assessmentsEnabled = false,
            recommendationsEnabled = false, freeTextParserReady = false }))
        : CallAsync((headers, deadline) => _client!.GetCapabilitiesAsync(new Empty(), headers, deadline, ct),
            value => new(200, new { value.Enabled, value.AssessmentsEnabled, value.RecommendationsEnabled,
                value.FreeTextParserReady }), ct);

    public Task<NutritionGatewayResponse> ExecuteAsync(CommandRequest request, CancellationToken ct) =>
        CallAsync((headers, deadline) => _client!.ExecuteAsync(request, headers, deadline, ct),
            value => Present(value, request.BeneficiaryId, request.Operation == CommandOperation.Assess ? 202 : 200), ct);

    public Task<NutritionGatewayResponse> ReadAsync(ResourceRequest request, CancellationToken ct) =>
        CallAsync((headers, deadline) => _client!.GetResourceAsync(request, headers, deadline, ct),
            value => Present(value, request.BeneficiaryId, 200), ct);

    public Task<NutritionGatewayResponse> PlansAsync(BeneficiaryRequest request, CancellationToken ct) =>
        CallAsync((headers, deadline) => _client!.ListMealPlansAsync(request, headers, deadline, ct), value =>
        {
            if (value.OutcomeCase == ResourceListResult.OutcomeOneofCase.Failure) return Failure(value.Failure);
            if (value.OutcomeCase != ResourceListResult.OutcomeOneofCase.Items || value.Items.Resources.Count > 20)
                throw new InvalidDataException();
            return new(200, value.Items.Resources.Select(resource => Map(resource, request.BeneficiaryId)).ToArray());
        }, ct);

    public Task<NutritionGatewayResponse> ReplacementsAsync(ReplacementOptionsRequest request, CancellationToken ct) =>
        CallAsync((headers, deadline) => _client!.GetReplacementOptionsAsync(request, headers, deadline, ct), value =>
        {
            if (value.OutcomeCase == RecipeListResult.OutcomeOneofCase.Failure) return Failure(value.Failure);
            if (value.OutcomeCase != RecipeListResult.OutcomeOneofCase.Items || value.Items.Recipes.Count > 20)
                throw new InvalidDataException();
            return new(200, value.Items.Recipes.Select(recipe => Json(recipe.DataJson)).ToArray());
        }, ct);

    private async Task<NutritionGatewayResponse> CallAsync<T>(Func<Metadata, DateTime, AsyncUnaryCall<T>> call,
        Func<T, NutritionGatewayResponse> present, CancellationToken ct)
    {
        if (!_options.Enabled) return Unavailable("nutrition.disabled");
        var bearer = _context.HttpContext?.Request.Headers.Authorization.ToString();
        if (string.IsNullOrWhiteSpace(bearer)) return Problem(401, "nutrition.unauthorized", "Vui lòng đăng nhập lại.");
        var headers = new Metadata { { "authorization", bearer }, { "x-nutrition-gateway-key", _options.ServiceKey } };
        try
        {
            using var pending = call(headers, DateTime.UtcNow.AddSeconds(_options.TimeoutSeconds));
            return present(await pending.ResponseAsync);
        }
        catch (RpcException) when (ct.IsCancellationRequested) { throw new OperationCanceledException(ct); }
        catch (RpcException exception)
        {
            return exception.StatusCode switch
            {
                StatusCode.Unauthenticated when exception.Status.Detail == "nutrition.gateway_unauthorized" =>
                    Unavailable("nutrition.gateway_unavailable"),
                StatusCode.Unauthenticated => Problem(401, "nutrition.unauthorized", "Vui lòng đăng nhập lại."),
                StatusCode.PermissionDenied => Problem(403, "nutrition.forbidden", "Không có quyền truy cập."),
                StatusCode.NotFound => Problem(404, "nutrition.not_found", "Không tìm thấy nội dung."),
                StatusCode.InvalidArgument => Problem(400, "nutrition.request", "Thông tin yêu cầu không hợp lệ."),
                StatusCode.ResourceExhausted => Problem(429, "nutrition.rate_limited", "Vui lòng thử lại sau."),
                _ => Unavailable("nutrition.service_unavailable")
            };
        }
        catch (Exception exception) when (exception is JsonException or InvalidDataException or ArgumentException or InvalidOperationException)
        {
            _logger.LogWarning("Invalid Nutrition RPC response, trace {TraceId}.", _context.HttpContext?.TraceIdentifier);
            return Unavailable("nutrition.service_unavailable");
        }
    }

    private static NutritionGatewayResponse Present(ResourceResult result, string beneficiary, int status) => result.OutcomeCase switch
    {
        ResourceResult.OutcomeOneofCase.Failure => Failure(result.Failure),
        ResourceResult.OutcomeOneofCase.Resource => new(status, Map(result.Resource, beneficiary)),
        _ => throw new InvalidDataException()
    };

    private static NutritionResourceResponse Map(Resource value, string beneficiary)
    {
        if (value.BeneficiaryId != beneficiary || !Guid.TryParseExact(value.Id, "D", out var id) || id == Guid.Empty ||
            value.HealthRevision < 1 || value.CreatedAt is null || value.Status.Length is < 1 or > 80)
            throw new InvalidDataException();
        return new(id, Guid.Parse(beneficiary), value.HealthRevision, value.Status,
            Json(value.DataJson), value.CreatedAt.ToDateTimeOffset());
    }

    private static JsonElement Json(string value)
    {
        using var document = JsonDocument.Parse(value, new JsonDocumentOptions { MaxDepth = 32 });
        if (document.RootElement.ValueKind != JsonValueKind.Object) throw new InvalidDataException();
        return document.RootElement.Clone();
    }

    private static NutritionGatewayResponse Failure(Failure failure) => failure.Kind switch
    {
        FailureKind.Validation => Problem(400, failure.Code, failure.Message),
        FailureKind.NotFound => Problem(404, failure.Code, failure.Message),
        FailureKind.Conflict => Problem(409, failure.Code, failure.Message),
        FailureKind.Forbidden => Problem(403, failure.Code, failure.Message),
        FailureKind.Unauthorized => Problem(401, failure.Code, failure.Message),
        FailureKind.RateLimited => Problem(429, failure.Code, failure.Message),
        _ => Unavailable(failure.Code)
    };

    private static NutritionGatewayResponse Unavailable(string code) => Problem(503, code,
        "Dịch vụ dinh dưỡng tạm thời chưa khả dụng. Thông tin đã nhập vẫn được giữ.");
    private static NutritionGatewayResponse Problem(int status, string code, string message) => new(status,
        new ProblemDetails { Status = status, Title = code, Detail = message });
    public void Dispose() => _channel?.Dispose();
}
