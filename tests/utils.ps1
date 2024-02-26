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

function funcB
{
    [CmdletBinding()]
    param([string]$action, [string] $value)

    switch ($action)
    {
        'throw' { throw $value }
        'write' { Write-Error $value -ErrorAction Stop }
        'pass' { $value | Out-Sentry }
        'pipeline'
        {
            try
            {
                throw $value
            }
            catch
            {
                [System.Management.Automation.ErrorRecord]$ErrorRecord = $_
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        }
    }
}

function ContextLines($start, $lines, $path = $null)
{
    if ($null -eq $path)
    {
        $path = $PSCommandPath
    }

    Get-Content $path | Select-Object -Skip ($start - 1) -First $lines
}

function StartSentryForEventTests([ref] $events, [ref] $transport)
{
    Start-Sentry {
        $_.Dsn = 'https://key@127.0.0.1/1'

        # Capture all events in BeforeSend callback & drop them.
        $_.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
                param([Sentry.SentryEvent]$e)
                $events.Add($e)
                return $e
            });

        # If events are not sent, there's a client report sent at the end and it blocks the process for the default flush
        # timeout because it cannot connect to the server. Let's just replace the transport too.
        $_.Transport = $transport.Value
    }
}

function GetListItem($list, $index)
{
    if ($index -ge 0)
    {
        return $list[$index]
    }
    else
    {
        return $list[$list.Count + $index]
    }
}
