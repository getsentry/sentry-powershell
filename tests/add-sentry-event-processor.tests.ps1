BeforeAll {
    . "$PSScriptRoot/utils.ps1"
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

    It 'Keeps the original event when the script block returns a non-SentryEvent value' {
        Add-SentryEventProcessor { 'not an event' }
        'msg' | Out-Sentry

        $events.Count | Should -Be 1
        $events[0].Message.Message | Should -Be 'msg'
    }

    It 'Chains multiple processors in registration order' {
        Add-SentryEventProcessor { $_.SetTag('first', '1'); $_ }
        Add-SentryEventProcessor { $_.SetTag('second', '2'); $_ }
        'msg' | Out-Sentry

        $events[0].Tags['first'] | Should -Be '1'
        $events[0].Tags['second'] | Should -Be '2'
    }

    It 'Still captures the event and logs a warning when the script block throws' {
        # Silent-failure contract: a throwing processor must not break event capture
        # or propagate the exception, and the failure must be logged.
        Stop-Sentry
        $logger = [TestLogger]::new([Sentry.SentryLevel]::Debug)
        Start-Sentry {
            $_.Dsn = 'https://key@127.0.0.1/1'
            # Debug=true is required for Sentry to retain a custom DiagnosticLogger;
            # see https://github.com/getsentry/sentry-dotnet/issues/3212
            $_.Debug = $true
            $_.DiagnosticLogger = $logger
            $_.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
                    param([Sentry.SentryEvent]$e)
                    $events.Add($e)
                    return $e
                })
            $_.Transport = $transport
        }

        Add-SentryEventProcessor { throw 'boom' }
        { 'msg' | Out-Sentry } | Should -Not -Throw

        $events.Count | Should -Be 1
        $events[0].Message.Message | Should -Be 'msg'
        ($logger.entries | Where-Object { $_ -match 'Event processor scriptblock failed' }).Count | Should -BeGreaterThan 0
    }

    It 'Throws when Sentry is not initialized' {
        Stop-Sentry
        { Add-SentryEventProcessor { $_ } } | Should -Throw '*Sentry is not initialized*'
    }
}
