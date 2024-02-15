BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $options = [Sentry.SentryOptions]::new()
    $options.Debug = $true
    $options.Dsn = 'https://key@127.0.0.1/1'
    $options.AutoSessionTracking = $false

    # Capture all events in BeforeSend callback & drop them.
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    $options.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
            param([Sentry.SentryEvent]$e)
            $events.Add($e)
            return $null
        });

    # If events are not sent, there's a client report sent at the end and it blocks the process for the default flush
    # timeout because it cannot connect to the server. Let's just replace the transport too.
    $options.Transport = [RecordingTransport]::new()

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
        FuncA ' ' 'message'
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 0

        $event.Message.Message | Should -Be 'message'

        $event.SentryThreads.Count | Should -Be 2
        [Sentry.SentryStackFrame[]] $frames = $event.SentryThreads[0].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -Be 'funcB'
        $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '        $param | Out-Sentry'
        $frames | Select-Object -Last 1 -ExpandProperty 'InApp' | Should -Be $true

        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'Function' | Should -Be 'funcA'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'ContextLine' | Should -Be '    funcB $action $param'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $true

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }

    It 'captures error record' {
        try
        {
            funcA 'throw' 'error'
        }
        catch
        {
            $_ | Out-Sentry
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[1].Type | Should -Be 'error'
        $event.SentryExceptions[1].Value | Should -Be 'error'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -Be 'funcB'
        $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ColumnNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '        throw $param'

        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'Function' | Should -Be 'funcA'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'ContextLine' | Should -Be '    funcB $action $param'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $true

        $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[0].Value | Should -Be 'error'
        $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

        $event.SentryThreads.Count | Should -Be 2
        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }

    It 'captures exception' {
        try
        {
            funcA 'throw' 'exception'
        }
        catch
        {
            $_.Exception | Out-Sentry
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[1].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[1].Value | Should -Be 'exception'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -Be '<ScriptBlock>'
        $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be $PSCommandPath
        $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '            $_.Exception | Out-Sentry'

        $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[0].Value | Should -Be 'exception'
        $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

        $event.SentryThreads.Count | Should -Be 2
        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }
}

Describe 'Invoke-WithSentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures error record' {
        try
        {
            Invoke-WithSentry { funcA 'throw' 'inside invoke' }
        }
        catch {}

        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[1].Type | Should -Be 'inside invoke'
        $event.SentryExceptions[1].Value | Should -Be 'inside invoke'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -Be 'funcB'
        $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ColumnNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '        throw $param'

        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'Function' | Should -Be 'funcA'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'AbsolutePath' | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'ContextLine' | Should -Be '    funcB $action $param'
        $frames | Select-Object -Last 2 | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $true

        $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[0].Value | Should -Be 'inside invoke'
        $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

        $event.SentryThreads.Count | Should -Be 2
        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }
}
