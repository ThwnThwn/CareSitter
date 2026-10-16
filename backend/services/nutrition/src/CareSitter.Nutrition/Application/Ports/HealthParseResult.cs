using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public sealed record HealthParseRequest(int SchemaVersion, long DictionaryRevision,
    IReadOnlyDictionary<string, string> Sources, IReadOnlyList<NutritionConcept> Concepts,
    HealthKnowledgeGraphContext Graph);

public sealed record HealthKnowledgeGraphContext(int SchemaVersion, long Revision, string RetrievalStrategy,
    HealthKnowledgeGraphNode[] Nodes, HealthKnowledgeGraphEdge[] Edges);

public sealed record HealthKnowledgeGraphNode(string Id, string Type, string Kind, string Code, string[] Aliases);

public sealed record HealthKnowledgeGraphEdge(string From, string To, string Relation, string[] EvidenceSourceIds);

public sealed record HealthParseResult(int SchemaVersion, long DictionaryRevision,
    HealthParseFact[] Facts, HealthUnresolvedStatement[] UnresolvedStatements, string[] IrrelevantSourceKeys);

public sealed record HealthParseFact(string Kind, string Code, string Label, string Assertion,
    string Temporality, string SourceKey, string Quote, string Subject, int StartOffset, int EndOffset);

public sealed record HealthUnresolvedStatement(string SourceKey, string Quote, int StartOffset, int EndOffset,
    string Reason);
