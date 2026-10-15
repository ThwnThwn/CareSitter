using System.Diagnostics.Metrics;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>Low-cardinality chat signals; never records IDs or message content.</summary>
public sealed class SupportChatMetrics
{
    private readonly Counter<long> _created;
    private readonly Counter<long> _messages;
    private readonly Counter<long> _replays;
    private readonly Counter<long> _versionConflicts;
    private readonly Counter<long> _fanoutFailures;

    public SupportChatMetrics(IMeterFactory meters)
    {
        var meter = meters.Create("CareSitter.SupportChat");
        _created = meter.CreateCounter<long>("support_chat_conversations_created_total");
        _messages = meter.CreateCounter<long>("support_chat_messages_committed_total");
        _replays = meter.CreateCounter<long>("support_chat_idempotency_replayed_total");
        _versionConflicts = meter.CreateCounter<long>("support_chat_version_conflict_total");
        _fanoutFailures = meter.CreateCounter<long>("support_chat_fanout_failure_total");
    }

    public void Created() => _created.Add(1);
    public void MessageCommitted(string role) => _messages.Add(1,
        new KeyValuePair<string, object?>("sender_role", role));
    public void Replayed(string operation) => _replays.Add(1,
        new KeyValuePair<string, object?>("operation", operation));
    public void VersionConflict() => _versionConflicts.Add(1);
    public void FanoutFailure(string eventName) => _fanoutFailures.Add(1,
        new KeyValuePair<string, object?>("event", eventName));
}
