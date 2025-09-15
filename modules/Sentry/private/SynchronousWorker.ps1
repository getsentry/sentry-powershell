. "$privateDir/New-HttpTransport.ps1"

class SynchronousWorker : Sentry.Extensibility.IBackgroundWorker
{
    hidden [Sentry.Extensibility.ITransport] $transport
    hidden [Sentry.SentryOptions] $options
    hidden $unfinishedTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()

    SynchronousWorker([Sentry.SentryOptions] $options)
    {
        $this.options = $options

        # Start from either the transport given on options, or create a new HTTP transport.
        $this.transport = $options.Transport;
        if ($null -eq $this.transport)
        {
            try
            {
                $this.transport = New-HttpTransport($options)
            }
            catch
            {
                if ($null -ne $options.DiagnosticLogger)
                {
                    $options.DiagnosticLogger.Log([Sentry.SentryLevel]::Warning, 'Failed to create HTTP transport in SynchronousWorker: {0}', $_.Exception, @())
                }
                throw
            }
        }
    }

    [bool] EnqueueEnvelope([Sentry.Protocol.Envelopes.Envelope] $envelope)
    {
        try
        {
            if ($null -eq $this.transport)
            {
                if ($null -ne $this.options.DiagnosticLogger)
                {
                    $this.options.DiagnosticLogger.Log([Sentry.SentryLevel]::Warning, 'Transport is null, cannot enqueue envelope', $null, @())
                }
                return $false
            }

            $task = $this.transport.SendEnvelopeAsync($envelope, [System.Threading.CancellationToken]::None)
            if (-not $task.Wait($this.options.FlushTimeout))
            {
                $this.unfinishedTasks.Add($task)
            }
            return $true
        }
        catch
        {
            if ($null -ne $this.options.DiagnosticLogger)
            {
                $this.options.DiagnosticLogger.Log([Sentry.SentryLevel]::Error, 'Failed to enqueue envelope: {0}', $_.Exception, @())
            }
            return $false
        }
    }

    [System.Threading.Tasks.Task] FlushAsync([System.TimeSpan] $timeout)
    {
        [System.Threading.Tasks.Task]::WhenAll($this.unfinishedTasks).Wait($timeout)
        $this.unfinishedTasks.Clear()
        return [System.Threading.Tasks.Task]::CompletedTask
    }

    [int] get_QueuedItems()
    {
        return $this.unfinishedTasks.Count
    }
}
