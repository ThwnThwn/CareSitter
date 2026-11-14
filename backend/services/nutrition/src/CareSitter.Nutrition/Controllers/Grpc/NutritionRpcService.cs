using System.Globalization;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Grpc.V1;
using CareSitter.Nutrition.Primitives;
using CareSitter.Nutrition.Infrastructure;
using Google.Protobuf.WellKnownTypes;
using global::Grpc.Core;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Controllers.Grpc;

[Authorize(Roles = "CUSTOMER")]
public sealed class NutritionRpcService(IMediator mediator, NutritionKnowledgeSearch knowledge, LocalKnowledgeAnswer localAnswer,
    GeminiKnowledgeAnswer gemini, IOptions<KnowledgeAnswerAiOptions> aiOptions) : NutritionRpc.NutritionRpcBase
{
    public override async Task<KnowledgeSearchResponse> SearchKnowledge(KnowledgeSearchRequest request, ServerCallContext context)
    {
        var query = request.Query.Trim();
        if (query.Length is < 3 or > 160) throw InvalidRequest();
        try
        {
            if (request.GeneralKnowledge)
            {
                if (request.LocalDemo || !aiOptions.Value.GeneralKnowledgeEnabled)
                    throw new RpcException(new Status(StatusCode.Unavailable, "nutrition.knowledge_unavailable"));
                // This path never reads the local book corpus or a beneficiary's health profile.
                var general = new KnowledgeSearchResponse { Query = query, GeneralKnowledge = true };
                ApplyAnswer(general, await gemini.AnswerAsync(query, [], context.CancellationToken));
                return general;
            }
            var localDemo = request.LocalDemo && knowledge.SupportsLocalDemo;
            var hits = await knowledge.FindAsync(query, context.CancellationToken, localDemo);
            var response = new KnowledgeSearchResponse { Query = query, LocalDemo = localDemo };
            if (localDemo)
            {
                if (aiOptions.Value.Enabled)
                {
                    var answer = await gemini.AnswerAsync(query, hits, context.CancellationToken);
                    ApplyAnswer(response, answer);
                }
                else
                {
                    var answer = await localAnswer.SelectEvidenceAsync(query, hits, context.CancellationToken);
                    response.AnswerStatus = answer.Status;
                    response.AnswerProvider = "Ollama";
                    response.AnswerChunkIds.AddRange(answer.ChunkIds);
                }
                if (response.AnswerChunkIds.FirstOrDefault() is { } answerId) response.AnswerChunkId = answerId;
            }
            response.Results.AddRange(hits.Select(hit => new CareSitter.Nutrition.Grpc.V1.KnowledgeHit
            {
                ChunkId = hit.ChunkId, Heading = hit.Heading, PdfPage = hit.PdfPage,
                PrintedPage = hit.PrintedPage ?? "", SourceTitle = hit.SourceTitle,
                SourceRevisionId = hit.SourceRevisionId, Excerpt = hit.Excerpt ?? ""
            }));
            return response;
        }
        catch (Exception error) when (error is InvalidOperationException or IOException or JsonException or
            UnauthorizedAccessException or KeyNotFoundException or FormatException)
        {
            throw new RpcException(new Status(StatusCode.Unavailable, "nutrition.knowledge_unavailable"));
        }
    }

    private static void ApplyAnswer(KnowledgeSearchResponse response, KnowledgeAiAnswer answer)
    {
        response.AnswerStatus = answer.Status;
        response.AnswerProvider = "Gemini";
        response.AnswerChunkIds.AddRange(answer.ChunkIds);
        foreach (var block in answer.Blocks)
        {
            var mapped = new CareSitter.Nutrition.Grpc.V1.KnowledgeAnswerBlock { Text = block.Text };
            mapped.ChunkIds.AddRange(block.ChunkIds);
            response.AnswerBlocks.Add(mapped);
        }
    }
    public override async Task<CapabilitiesResponse> GetCapabilities(Empty request, ServerCallContext context)
    {
        var value = await mediator.Send(new NutritionCapabilitiesQuery(), context.CancellationToken);
        return new CapabilitiesResponse
        {
            Enabled = value.Enabled, AssessmentsEnabled = value.AssessmentsEnabled,
            RecommendationsEnabled = value.RecommendationsEnabled,
            FreeTextParserReady = value.FreeTextParserReady,
            Disclaimer = value.Disclaimer,
            DisclaimerVersion = value.DisclaimerVersion
        };
    }

    public override async Task<ResourceResult> Execute(CommandRequest request, ServerCallContext context)
    {
        DateOnly? plannedDate = null;
        if (request.HasPlannedDate)
        {
            if (!DateOnly.TryParseExact(request.PlannedDate, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var date)) throw InvalidRequest();
            plannedDate = date;
        }
        if (request.HasMealType && request.MealType.Length > 32) throw InvalidRequest();
        var beneficiary = Id(request.BeneficiaryId);
        var resource = OptionalId(request.HasResourceId, request.ResourceId);
        var input = new NutritionWriteInput(request.ExpectedHealthRevision, Id(request.IdempotencyKey),
            OptionalId(request.HasAssessmentId, request.AssessmentId), plannedDate,
            OptionalId(request.HasRecipeVersionId, request.RecipeVersionId), request.HasMealType ? request.MealType : null)
        { FingerprintResourceId = resource };
        NutritionWriteCommand command = request.Operation switch
        {
            CommandOperation.Assess => new AssessNutritionCommand(beneficiary, input),
            CommandOperation.Confirm => new ConfirmNutritionCommand(beneficiary, resource ?? Guid.Empty, input),
            CommandOperation.Recommend => new RecommendMealsCommand(beneficiary, input),
            CommandOperation.Replace => new ReplaceMealCommand(beneficiary, resource ?? Guid.Empty, input),
            CommandOperation.Save => new SaveMealPlanCommand(beneficiary, resource ?? Guid.Empty, input),
            _ => throw InvalidRequest()
        };
        return Present(await mediator.Send(command, context.CancellationToken));
    }

    public override async Task<ResourceResult> GetResource(ResourceRequest request, ServerCallContext context)
    {
        var kind = request.Kind switch
        {
            ResourceKind.Assessment => "assessment", ResourceKind.Recommendation => "recommendation",
            ResourceKind.Plan => "plan", _ => throw InvalidRequest()
        };
        return Present(await mediator.Send(new NutritionResourceQuery(kind, Id(request.BeneficiaryId), Id(request.ResourceId)),
            context.CancellationToken));
    }

    public override async Task<ResourceListResult> ListMealPlans(BeneficiaryRequest request, ServerCallContext context)
    {
        DateOnly? weekStart = null;
        if (request.HasWeekStart)
        {
            if (!DateOnly.TryParseExact(request.WeekStart, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var date)) throw InvalidRequest();
            weekStart = date;
        }
        var result = await mediator.Send(new ListMealPlansQuery(Id(request.BeneficiaryId), weekStart), context.CancellationToken);
        if (result.IsFailure) return new ResourceListResult { Failure = Failure(result.Error) };
        var list = new ResourceList();
        list.Resources.AddRange(result.Value.Select(Map));
        return new ResourceListResult { Items = list };
    }

    public override async Task<RecipeListResult> GetReplacementOptions(ReplacementOptionsRequest request, ServerCallContext context)
    {
        if (request.MealType.Length > 32) throw InvalidRequest();
        var result = await mediator.Send(new ReplacementOptionsQuery(Id(request.BeneficiaryId), Id(request.RecommendationId),
            request.MealType), context.CancellationToken);
        if (result.IsFailure) return new RecipeListResult { Failure = Failure(result.Error) };
        var list = new RecipeList();
        list.Recipes.AddRange(result.Value.Select(value => new RecipeOption { DataJson = NutritionJson.Write(value) }));
        return new RecipeListResult { Items = list };
    }

    private static ResourceResult Present(Result<ResourceResponse> result) => result.IsFailure
        ? new ResourceResult { Failure = Failure(result.Error) } : new ResourceResult { Resource = Map(result.Value) };

    private static Resource Map(ResourceResponse value) => new()
    {
        Id = value.Id.ToString(), BeneficiaryId = value.BeneficiaryId.ToString(), HealthRevision = value.HealthRevision,
        Status = value.Status, DataJson = value.Data.GetRawText(), CreatedAt = Timestamp.FromDateTimeOffset(value.CreatedAt)
    };

    private static Failure Failure(Error error) => new()
    {
        Code = error.Code, Message = error.Message, Kind = error.Type switch
        {
            ErrorType.Validation => FailureKind.Validation, ErrorType.NotFound => FailureKind.NotFound,
            ErrorType.Conflict => FailureKind.Conflict, ErrorType.Forbidden => FailureKind.Forbidden,
            ErrorType.Unauthorized => FailureKind.Unauthorized, ErrorType.RateLimited => FailureKind.RateLimited,
            _ => FailureKind.Unavailable
        }
    };

    private static Guid Id(string value) => Guid.TryParseExact(value, "D", out var id) && id != Guid.Empty
        ? id : throw InvalidRequest();
    private static Guid? OptionalId(bool present, string value) => present ? Id(value) : null;
    private static RpcException InvalidRequest() => new(new Status(StatusCode.InvalidArgument, "nutrition.request"));
}
