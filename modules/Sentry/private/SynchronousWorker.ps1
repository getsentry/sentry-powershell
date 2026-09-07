class SynchronousWorker : Sentry.Extensibility.IBackgroundWorker {
    hidden [Sentry.Extensibility.ITransport] $transport
    hidden [Sentry.SentryOptions] $options
    hidden $unfinishedTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()

    SynchronousWorker([Sentry.SentryOptions] $options) {
        # No fallback: the SDK builds its own default worker and transport when BackgroundWorker is left unset.
        if ($null -eq $options.Transport) {
            throw 'SynchronousWorker requires options.Transport to be set.'
        }

        $this.options = $options
        $this.transport = $options.Transport
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
