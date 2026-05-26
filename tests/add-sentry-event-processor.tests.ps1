BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
}

Describe 'Add-SentryEventProcessor' {
    BeforeEach {
        $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
        $transport = [RecordingTransport]::new()
        StartSentryForEventTests ([ref] $events) ([ref] $transport)
    }

    AfterEach {
        $events.Clear()
        Stop-Sentry
    }

    It 'Mutates events via $_' {
        Add-SentryEventProcessor { $_.SetTag('custom', 'value'); $_ }
        'msg' | Out-Sentry

        $events[0].Tags['custom'] | Should -Be 'value'
    }

    It 'Drops events when the script block returns $null' {
        Add-SentryEventProcessor {
            if ($_.Message.Message -match 'drop-me') { return $null }
            $_
        }
        'drop-me please' | Out-Sentry
        'keep this one' | Out-Sentry

        $events.Count | Should -Be 1
        $events[0].Message.Message | Should -Be 'keep this one'
    }

    It 'Chains multiple processors in registration order' {
        Add-SentryEventProcessor { $_.SetTag('first', '1'); $_ }
        Add-SentryEventProcessor { $_.SetTag('second', '2'); $_ }
        'msg' | Out-Sentry

        $events[0].Tags['first'] | Should -Be '1'
        $events[0].Tags['second'] | Should -Be '2'
    }

    It 'Throws when Sentry is not initialized' {
        Stop-Sentry
        { Add-SentryEventProcessor { $_ } } | Should -Throw '*Sentry is not initialized*'
    }
}
