Describe 'Sentry' {
    BeforeAll {
        class RecordingTransport:Sentry.Extensibility.ITransport
        {
            $envelopes = [System.Collections.Concurrent.ConcurrentQueue[Sentry.Protocol.Envelopes.Envelope]]::new();

            [System.Threading.Tasks.Task]SendEnvelopeAsync([Sentry.Protocol.Envelopes.Envelope] $envelope, [System.Threading.CancellationToken] $cancellationToken)
            {
                $this.envelopes.Enqueue($envelope);
                return [System.Threading.Tasks.Task]::CompletedTask;
            }
        }

        $transport = [RecordingTransport]::new()

        $options = [Sentry.SentryOptions]::new()
        $options.Debug = $true
        $options.Dsn = 'https://key@127.0.0.1/1'
        $options.Transport = $transport;
        [Sentry.SentrySdk]::init($options)
    }

    AfterAll {
        [Sentry.SentrySdk]::close()
    }

    It 'pipeline captures message' {
        'foo' | Sentry
    }

    It 'pipeline captures error record' {
        try
        {
            throw 'hello'
        }
        catch
        {
            $_ | Sentry
        }
    }

    It 'pipeline aptures exception' {
        try
        {
            throw 'hello'
        }
        catch
        {
            $_.Exception | Sentry
        }
    }

    It 'invoke captures error record' {
        Invoke-WithSentry { throw 'hello' }
    }

}
