BeforeAll {
    $events = [System.Collections.Concurrent.ConcurrentQueue[Sentry.SentryEvent]]::new();
    $options = [Sentry.SentryOptions]::new()
    $options.Debug = $true
    $options.Dsn = 'https://key@127.0.0.1/1'
    $options.AutoSessionTracking = $false
    $options.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
            param([Sentry.SentryEvent]$e)
            $events.Enqueue($e)
            return $null # Prevent sending
        });
    [Sentry.SentrySdk]::init($options)
}

AfterAll {
    [Sentry.SentrySdk]::Close()
}


Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures message' {
        'message' | Out-Sentry
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Exception | Should -Be $null
        $event.Message.Message | Should -Be 'message'
    }

    It 'captures error record' {
        try
        {
            throw 'error'
        }
        catch
        {
            $_ | Out-Sentry
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
        $event.Exception.Message | Should -Be 'error'
    }

    It 'captures exception' {
        try
        {
            throw 'exception'
        }
        catch
        {
            $_.Exception | Out-Sentry
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
        $event.Exception.Message | Should -Be 'exception'
    }
}

Describe 'Invoke-WithSentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures error record' {
        try
        {
            Invoke-WithSentry { throw 'inside invoke' }
        }
        catch {}
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
        $event.Exception.Message | Should -Be 'inside invoke'
    }
}
