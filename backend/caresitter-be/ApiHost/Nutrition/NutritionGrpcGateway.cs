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
                value.FreeTextParserReady, value.Disclaimer, value.DisclaimerVersion }), ct);

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

    public Task<NutritionGatewayResponse> KnowledgeAsync(string query, CancellationToken ct, bool localDemo = false,
        bool generalKnowledge = false) =>
        CallAsync((headers, deadline) => _client!.SearchKnowledgeAsync(
            new KnowledgeSearchRequest { Query = query, LocalDemo = localDemo, GeneralKnowledge = generalKnowledge }, headers, deadline, ct), value =>
        {
            var onlineReference = generalKnowledge && value.ReferenceKnowledge && !value.LocalDemo && !value.GeneralKnowledge;
            if (generalKnowledge && !onlineReference) return PresentGeneralKnowledge(query, value);
            if (value.GeneralKnowledge || value.ReferenceKnowledge && !onlineReference) throw new InvalidDataException();
            if (value.Query != query || value.Results.Count > 10 ||
                value.Results.Select(hit => hit.ChunkId).Distinct(StringComparer.Ordinal).Count() != value.Results.Count || value.Results.Any(hit =>
                    string.IsNullOrWhiteSpace(hit.ChunkId) || hit.Heading.Length > 500 ||
                    hit.SourceTitle.Length > 500 || hit.SourceRevisionId.Length > 200))
                throw new InvalidDataException();
            var showPassages = localDemo && value.LocalDemo || onlineReference;
            if (onlineReference && (value.AnswerProvider != "Gemini" || value.Results.Any(hit => hit.PdfPage < 1 || string.IsNullOrWhiteSpace(hit.SourceTitle) ||
                string.IsNullOrWhiteSpace(hit.SourceRevisionId) || hit.Excerpt.Length is < 18 or > 640)))
                throw new InvalidDataException();
            var answerIds = showPassages
                ? (value.AnswerChunkIds.Count > 0 ? value.AnswerChunkIds.ToArray() :
                    string.IsNullOrEmpty(value.AnswerChunkId) ? [] : new[] { value.AnswerChunkId })
                : [];
            if (answerIds.Length > 5 || answerIds.Distinct(StringComparer.Ordinal).Count() != answerIds.Length ||
                answerIds.Any(id => !value.Results.Any(hit => hit.ChunkId == id && hit.Excerpt.Length is > 0 and <= 640)))
                throw new InvalidDataException();
            var suggestion = showPassages && value.AnswerStatus == "ai_suggestion";
            if (suggestion && (value.AnswerProvider != "Gemini" || answerIds.Length != 0 || value.AnswerBlocks.Count == 0))
                throw new InvalidDataException();
            var status = suggestion ? "ai_suggestion" : !showPassages ? null : answerIds.Length > 0 ? "answered" :
                value.AnswerStatus is "unavailable" or "not_configured" or "rate_limited" or "timeout" or "invalid_output"
                    ? value.AnswerStatus : "insufficient_evidence";
            var blocks = showPassages ? value.AnswerBlocks.ToArray() : [];
            if (blocks.Length > 4 || blocks.Any(block => block.Text.Length is < 10 or > 1200 ||
                    (suggestion ? block.ChunkIds.Count != 0 : block.ChunkIds.Count is < 1 or > 5) || block.ChunkIds.Distinct(StringComparer.Ordinal).Count() != block.ChunkIds.Count ||
                    block.ChunkIds.Any(id => !answerIds.Contains(id, StringComparer.Ordinal))) ||
                blocks.Length > 0 && !blocks.SelectMany(block => block.ChunkIds).ToHashSet(StringComparer.Ordinal).SetEquals(answerIds))
                throw new InvalidDataException();
            return new(200, new NutritionKnowledgeSearchResponse(value.Query,
                value.Results.Select(hit => new NutritionKnowledgeHitResponse(hit.ChunkId, hit.Heading,
                    hit.PdfPage, string.IsNullOrEmpty(hit.PrintedPage) ? null : hit.PrintedPage,
                    hit.SourceTitle, hit.SourceRevisionId,
                    showPassages && hit.Excerpt.Length is > 0 and <= 640 ? hit.Excerpt : null)).ToArray(),
                answerIds.FirstOrDefault(), localDemo && value.LocalDemo, answerIds, status,
                blocks.Select(block => new NutritionKnowledgeAnswerBlockResponse(block.Text, block.ChunkIds.ToArray())).ToArray(),
                showPassages && value.AnswerProvider is "Gemini" or "Ollama" ? value.AnswerProvider : null,
                ReferenceKnowledge: onlineReference));
        }, ct, _options.KnowledgeTimeoutSeconds);

    private static NutritionGatewayResponse PresentGeneralKnowledge(string query, KnowledgeSearchResponse value)
    {
        // General answers carry no corpus text, source IDs or purported book citations.
        var blocks = value.AnswerBlocks.ToArray();
        if (value.Query != query || !value.GeneralKnowledge || value.ReferenceKnowledge || value.LocalDemo || value.Results.Count != 0 ||
            !string.IsNullOrEmpty(value.AnswerChunkId) || value.AnswerChunkIds.Count != 0 ||
            value.AnswerProvider != "Gemini" ||
            value.AnswerStatus is not ("ai_suggestion" or "insufficient_evidence" or "unavailable" or
                "not_configured" or "rate_limited" or "timeout" or "invalid_output") ||
            blocks.Length > 4 || (value.AnswerStatus == "ai_suggestion" ? blocks.Length == 0 : blocks.Length != 0) ||
            blocks.Any(block => block.Text.Trim().Length < 10 || block.Text.Length > 1200 || block.ChunkIds.Count != 0))
            throw new InvalidDataException();
        return new(200, new NutritionKnowledgeSearchResponse(query, [], AnswerChunkIds: [],
            AnswerStatus: value.AnswerStatus, AnswerBlocks: blocks.Select(block =>
                new NutritionKnowledgeAnswerBlockResponse(block.Text, [])).ToArray(),
            AnswerProvider: "Gemini", GeneralKnowledge: true));
    }

    private async Task<NutritionGatewayResponse> CallAsync<T>(Func<Metadata, DateTime, AsyncUnaryCall<T>> call,
        Func<T, NutritionGatewayResponse> present, CancellationToken ct, int? timeoutSeconds = null)
    {
        if (!_options.Enabled) return Unavailable("nutrition.disabled");
        var bearer = _context.HttpContext?.Request.Headers.Authorization.ToString();
        if (string.IsNullOrWhiteSpace(bearer)) return Problem(401, "nutrition.unauthorized", "Vui lòng đăng nhập lại.");
        var headers = new Metadata { { "authorization", bearer }, { "x-nutrition-gateway-key", _options.ServiceKey } };
        try
        {
            using var pending = call(headers, DateTime.UtcNow.AddSeconds(timeoutSeconds ?? _options.TimeoutSeconds));
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
