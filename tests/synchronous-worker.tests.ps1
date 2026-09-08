BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    . "$PSScriptRoot/../modules/Sentry/private/SynchronousWorker.ps1"
    . "$PSScriptRoot/../modules/Sentry/private/Get-CurrentOptions.ps1"
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
}

Describe 'SynchronousWorker' {
    It 'throws when options.Transport is not set' {
        # Only reachable when the SynchronousTransport constructor threw.
        $options = [Sentry.SentryOptions]::new()
        $options.Transport | Should -Be $null
        { [SynchronousWorker]::new($options) } | Should -Throw '*requires options.Transport*'
    }

    It 'sends envelopes through the transport from options' {
        $options = [Sentry.SentryOptions]::new()
        $options.Dsn = 'https://key@127.0.0.1/1'
        $options.Transport = [RecordingTransport]::new()

        $sut = [SynchronousWorker]::new($options)
        $envelope = [Sentry.Protocol.Envelopes.Envelope]::FromEvent([Sentry.SentryEvent]::new(), $null, $null, $null)
        $sut.EnqueueEnvelope($envelope) | Should -Be $true

        $options.Transport.envelopes.Count | Should -Be 1
        $sut.get_QueuedItems() | Should -Be 0
    }
}

Describe 'Start-Sentry worker composition' {
    AfterEach {
        Stop-Sentry
    }

    It 'wires a SynchronousWorker on top of a SynchronousTransport' {
        Start-Sentry { $_.Dsn = 'https://key@127.0.0.1/1' }

        $options = Get-CurrentOptions
        $options.Transport.GetType().Name | Should -Be 'SynchronousTransport'
        $options.BackgroundWorker.GetType().Name | Should -Be 'SynchronousWorker'
    }

    It 'keeps a transport supplied through options' {
        $transport = [RecordingTransport]::new()
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            $_.Transport = $transport
        }

        $options = Get-CurrentOptions
        $options.Transport | Should -Be $transport
        $options.BackgroundWorker.GetType().Name | Should -Be 'SynchronousWorker'
    }
}
