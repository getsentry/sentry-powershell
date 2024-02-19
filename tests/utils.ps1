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

function StartSentryForEventTests([ref]  $events)
{
    $options = [Sentry.SentryOptions]::new()
    $options.Dsn = 'https://key@127.0.0.1/1'

    # Capture all events in BeforeSend callback & drop them.
    $options.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
            param([Sentry.SentryEvent]$e)
            $events.Add($e)
            return $null
        });

    # If events are not sent, there's a client report sent at the end and it blocks the process for the default flush
    # timeout because it cannot connect to the server. Let's just replace the transport too.
    $options.Transport = [RecordingTransport]::new()

    Start-Sentry $options
}

function GetListItem($list, $index)
{
    if ($index -ge 0)
    {
        $list = $list[$index]
    }
    else
    {
        $list[$list.Count + $index]
    }
}
