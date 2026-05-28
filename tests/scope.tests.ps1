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

    It 'resolves relative paths against PowerShell $PWD, not [Environment]::CurrentDirectory' {
        # Simulate the common case where PowerShell's location diverges from the
        # process working directory (which is what .NET I/O uses for relative paths).
        $originalLocation = Get-Location
        $originalEnvCwd = [Environment]::CurrentDirectory
        try {
            $tempDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString()))
            $relativeName = 'attachment-relative.txt'
            $fileContents = 'hello from a relative path'
            Set-Content -Path (Join-Path $tempDir $relativeName) -Value $fileContents -NoNewline
            Set-Location $tempDir
            # Force divergence: leave [Environment]::CurrentDirectory pointed elsewhere.
            [Environment]::CurrentDirectory = $originalEnvCwd

            Add-SentryAttachment -Path $relativeName
            'message' | Out-Sentry

            $envelope = [Sentry.Protocol.Envelopes.Envelope]$transport.Envelopes.ToArray()[0]
            $envelope.Items[1].Header.filename | Should -Be $relativeName
            # The envelope serializer reads the file lazily — if the path didn't resolve,
            # we'd see an empty/zero-length payload instead of the real bytes.
            $envelope.Items[1].Header.length | Should -Be $fileContents.Length
        } finally {
            Set-Location $originalLocation
            [Environment]::CurrentDirectory = $originalEnvCwd
            # On Windows the SDK may still have a handle on the attachment file
            # until Stop-Sentry runs in AfterEach, so cleanup can race. The temp
            # dir is harmless to leave behind, so don't fail the test over it.
            if ($tempDir -and (Test-Path $tempDir)) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
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
