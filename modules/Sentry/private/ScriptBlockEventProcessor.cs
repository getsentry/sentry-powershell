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
            // ScriptBlock.Invoke is not annotated and in practice always returns a
            // Collection<PSObject>, but guard against null defensively and treat it
            // the same as "no pipeline output" -> leave the event unchanged.
            var results = _scriptBlock.Invoke(@event);
            if (results == null || results.Count == 0)
            {
                return @event;
            }

            var last = results[results.Count - 1];
            if (last == null)
            {
                // User's script block explicitly returned $null -> drop the event.
                return null;
            }

            var processed = last.BaseObject as SentryEvent;
            if (processed != null)
            {
                return processed;
            }

            if (_logger != null)
            {
                var returnedTypeName = last.BaseObject != null ? last.BaseObject.GetType().FullName : "null";
                _logger.Log(
                    SentryLevel.Warning,
                    "Event processor scriptblock for event {0} returned {1} instead of a SentryEvent; keeping the original event.",
                    null,
                    new object[] { @event.EventId, returnedTypeName });
            }
            return @event;
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
