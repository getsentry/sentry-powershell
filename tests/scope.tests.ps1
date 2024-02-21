BeforeAll {
    . "$PSScriptRoot/utils.ps1"
}


Describe 'Edit-SentryScope' {
    BeforeEach {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        $transport = [RecordingTransport]::new()
        StartSentryForEventTests ([ref] $events) ([ref] $transport)
    }

    AfterEach {
        Stop-Sentry
    }

    It 'adds a file attachment via global scope' {
        Edit-SentryScope {
            [Sentry.ScopeExtensions]::AddAttachment($_, $PSCommandPath)
        }
        'message' | Out-Sentry
        [Sentry.SentrySdk]::Flush()
        $transport.Envelopes.Count | Should -Be 1
        [Sentry.Protocol.Envelopes.Envelope]$envelope = $transport.Envelopes.ToArray()[0]
        $envelope.Items.Count | Should -Be 2
        $envelope.Items[1].Header.type | Should -Be 'attachment'
        $envelope.Items[1].Header.filename | Should -Be 'scope.tests.ps1'
    }

    It 'adds a byte attachment via local scope' {
        'message' | Out-Sentry -EditScope {
            [byte[]] $data = 1, 2, 3, 4, 5
            [Sentry.ScopeExtensions]::AddAttachment($_, $data, 'filename.bin')
        }
        [Sentry.SentrySdk]::Flush()
        $transport.Envelopes.Count | Should -Be 1
        [Sentry.Protocol.Envelopes.Envelope]$envelope = $transport.Envelopes.ToArray()[0]
        $envelope.Items.Count | Should -Be 2
        $envelope.Items[1].Header.type | Should -Be 'attachment'
        $envelope.Items[1].Header.filename | Should -Be 'filename.bin'
    }
}
