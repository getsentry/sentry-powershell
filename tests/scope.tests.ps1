BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
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
        Edit-SentryScope { $_.AddAttachment($PSCommandPath) }
        'message' | Out-Sentry
        $transport.Envelopes.Count | Should -Be 1
        [Sentry.Protocol.Envelopes.Envelope]$envelope = $transport.Envelopes.ToArray()[0]
        $envelope.Items.Count | Should -Be 2
        $envelope.Items[1].Header.type | Should -Be 'attachment'
        $envelope.Items[1].Header.filename | Should -Be 'scope.tests.ps1'
    }

    It 'adds a byte attachment via local scope' {
        'message' | Out-Sentry -EditScope {
            [byte[]] $data = 1, 2, 3, 4, 5
            $_.AddAttachment($data, 'filename.bin')
        }
        $transport.Envelopes.Count | Should -Be 1
        [Sentry.Protocol.Envelopes.Envelope]$envelope = $transport.Envelopes.ToArray()[0]
        $envelope.Items.Count | Should -Be 2
        $envelope.Items[1].Header.type | Should -Be 'attachment'
        $envelope.Items[1].Header.filename | Should -Be 'filename.bin'
    }
}

Describe 'Add-SentryAttachment' {
    BeforeEach {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        $transport = [RecordingTransport]::new()
        StartSentryForEventTests ([ref] $events) ([ref] $transport)
    }

    AfterEach {
        Stop-Sentry
    }

    It 'infers text/plain for a .ps1 file' {
        Add-SentryAttachment -Path $PSCommandPath
        'message' | Out-Sentry
        $envelope = [Sentry.Protocol.Envelopes.Envelope]$transport.Envelopes.ToArray()[0]
        $envelope.Items[1].Header.filename | Should -Be 'scope.tests.ps1'
        $envelope.Items[1].Header.content_type | Should -Be 'text/plain'
    }

    It 'infers application/json for a .json byte attachment' {
        [byte[]] $data = [System.Text.Encoding]::UTF8.GetBytes('{"hello":"world"}')
        Add-SentryAttachment -Bytes $data -FileName 'payload.json'
        'message' | Out-Sentry
        $envelope = [Sentry.Protocol.Envelopes.Envelope]$transport.Envelopes.ToArray()[0]
        $envelope.Items[1].Header.filename | Should -Be 'payload.json'
        $envelope.Items[1].Header.content_type | Should -Be 'application/json'
    }

    It 'honors an explicit -ContentType' {
        Add-SentryAttachment -Path $PSCommandPath -ContentType 'text/x-powershell'
        'message' | Out-Sentry
        $envelope = [Sentry.Protocol.Envelopes.Envelope]$transport.Envelopes.ToArray()[0]
        $envelope.Items[1].Header.content_type | Should -Be 'text/x-powershell'
    }

    It 'leaves content-type unset for unknown extensions' {
        [byte[]] $data = 1, 2, 3
        Add-SentryAttachment -Bytes $data -FileName 'thing.unknownext'
        'message' | Out-Sentry
        $envelope = [Sentry.Protocol.Envelopes.Envelope]$transport.Envelopes.ToArray()[0]
        $envelope.Items[1].Header.filename | Should -Be 'thing.unknownext'
        # When no extension match and no explicit override, we don't set a content type.
        [string]::IsNullOrEmpty($envelope.Items[1].Header.content_type) | Should -Be $true
    }
}
