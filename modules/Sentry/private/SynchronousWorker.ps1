. "$privateDir/New-HttpTransport.ps1"

class SynchronousWorker : Sentry.Extensibility.IBackgroundWorker {
    hidden [Sentry.Extensibility.ITransport] $transport
    hidden [Sentry.SentryOptions] $options
    hidden $unfinishedTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()

    SynchronousWorker([Sentry.SentryOptions] $options) {
        $this.options = $options

        # Start from either the transport given on options, or create a new HTTP transport.
        $this.transport = $options.Transport;
        if ($null -eq $this.transport) {
            $this.transport = New-HttpTransport($options)
        }
    }

    [bool] EnqueueEnvelope([Sentry.Protocol.Envelopes.Envelope] $envelope) {
        $task = $this.transport.SendEnvelopeAsync($envelope, [System.Threading.CancellationToken]::None)
        if (-not $task.Wait($this.options.FlushTimeout)) {
            $this.unfinishedTasks.Add($task)
        }
        return $true
    }

    [System.Threading.Tasks.Task] FlushAsync([System.TimeSpan] $timeout) {
        [System.Threading.Tasks.Task]::WhenAll($this.unfinishedTasks).Wait($timeout)
        $this.unfinishedTasks.Clear()
        return [System.Threading.Tasks.Task]::CompletedTask
    }

    [int] get_QueuedItems() {
        return $this.unfinishedTasks.Count
    }
}
