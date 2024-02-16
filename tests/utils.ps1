class RecordingTransport:Sentry.Extensibility.ITransport
{
    $envelopes = [System.Collections.Concurrent.ConcurrentQueue[Sentry.Protocol.Envelopes.Envelope]]::new();

    [System.Threading.Tasks.Task]SendEnvelopeAsync([Sentry.Protocol.Envelopes.Envelope] $envelope, [System.Threading.CancellationToken] $cancellationToken)
    {
        $this.envelopes.Enqueue($envelope);
        return [System.Threading.Tasks.Task]::CompletedTask;
    }
}

class TestLogger:Sentry.Infrastructure.DiagnosticLogger
{
    TestLogger([Sentry.SentryLevel]$level) : base($level) {}

    $entries = [System.Collections.Concurrent.ConcurrentQueue[string]]::new();

    [void]LogMessage([string] $message) { $this.entries.Enqueue($message); }
}
class TestIntegration : Sentry.Integrations.ISdkIntegration
{
    [Sentry.SentryOptions] $Options
    [Sentry.IHub] $Hub

    Register([Sentry.IHub] $hub, [Sentry.SentryOptions] $options)
    {
        $this.Hub = $hub
        $this.Options = $options
    }
}

function funcA($action, $param)
{
    funcB $action $param
}
function funcB($action, $param)
{
    if ($action -eq 'throw')
    {
        throw $param
    }
    else
    {
        $param | Out-Sentry
    }
}
