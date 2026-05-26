using System;
using System.Management.Automation;
using Sentry;
using Sentry.Extensibility;

// Wraps a PowerShell ScriptBlock as an ISentryEventProcessor so the public
// Add-SentryEventProcessor cmdlet can register user-supplied script blocks with
// the Sentry pipeline. Implementing the interface in C# (rather than asking users
// to author a PowerShell class deriving from an internal base) keeps the public
// API a single scriptblock and avoids the `Process` keyword conflict in Windows
// PowerShell that would otherwise require a Process_ / DoProcess workaround.
public sealed class ScriptBlockEventProcessor : ISentryEventProcessor
{
    private readonly ScriptBlock _scriptBlock;
    private readonly IDiagnosticLogger _logger;

    public ScriptBlockEventProcessor(ScriptBlock scriptBlock, IDiagnosticLogger logger)
    {
        if (scriptBlock == null) throw new ArgumentNullException("scriptBlock");
        _scriptBlock = scriptBlock;
        _logger = logger;
    }

    public SentryEvent Process(SentryEvent @event)
    {
        try
        {
            var results = _scriptBlock.Invoke(@event);
            if (results == null || results.Count == 0)
            {
                return @event;
            }

            var last = results[results.Count - 1];
            if (last == null)
            {
                return null;
            }

            return (last.BaseObject as SentryEvent) ?? @event;
        }
        catch (Exception ex)
        {
            if (_logger != null)
            {
                _logger.Log(
                    SentryLevel.Warning,
                    "Event processor scriptblock failed for event {0}: {1}",
                    ex,
                    new object[] { @event.EventId, ex.Message });
            }
            return @event;
        }
    }
}
