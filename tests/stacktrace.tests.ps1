BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    $transport = [RecordingTransport]::new()
    StartSentryForEventTests ([ref] $events) ([ref] $transport)

    $checkFrame = {
        param([Sentry.SentryStackFrame] $frame, [string] $funcName, [int] $funcLine)
        $frame.Function | Should -Be $funcName
        $frame.AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        $frame.LineNumber | Should -BeGreaterThan 0
        $frame.InApp | Should -Be $true
        $frame.PreContext  | Should -Be (ContextLines -Start ($funcLine - 5) -Lines 5)
        $frame.ContextLine | Should -Be (ContextLines -Start $funcLine -Lines 1)
        $frame.PostContext | Should -Be (ContextLines -Start ($funcLine + 1) -Lines 5)
    }

    $checkErrorRecord = {
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[1].Type | Should -Be 'error'
        $event.SentryExceptions[1].Value | Should -Be 'error'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0

        $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 42)
        $(GetListItem $frames -1).ColumnNumber | Should -BeGreaterThan 0

        $checkFrame.Invoke((GetListItem $frames -2), 'funcA', 35)

        $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[0].Value | Should -Be 'error'
        $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

        $event.SentryThreads.Count | Should -Be 2
        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }
}

AfterAll {
    Stop-Sentry
}

Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures message' {
        FuncA 'pass' 'message'
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions | Should -Be @()

        $event.Message.Message | Should -Be 'message'

        $event.SentryThreads.Count | Should -Be 2
        [Sentry.SentryStackFrame[]] $frames = $event.SentryThreads[0].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 45)
        $checkFrame.Invoke((GetListItem $frames -2), 'funcA', 35)

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

        @($null) | ForEach-Object $checkErrorRecord
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
        (GetListItem $frames -1).Function | Should -Be '<ScriptBlock>'
        (GetListItem $frames -1).AbsolutePath | Should -Be $PSCommandPath
        (GetListItem $frames -1).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).InApp | Should -Be $true
        (GetListItem $frames -1).PreContext | Should -Be @('        {', "            funcA 'throw' 'exception'", '        }', '        catch', '        {')
        (GetListItem $frames -1).ContextLine | Should -Be '            $_.Exception | Out-Sentry'
        (GetListItem $frames -1).PostContext | Should -Be @('        }', '        $events.Count | Should -Be 1', '        [Sentry.SentryEvent]$event = $events.ToArray()[0]', '        $event.SentryExceptions.Count | Should -Be 2', '')

        $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[0].Value | Should -Be 'exception'
        $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

        $event.SentryThreads.Count | Should -Be 2
        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }

    It 'does not add stack trace to message when AttachStacktrace=false' {
        $bindingFlags = [System.Reflection.BindingFlags]::Static + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public
        $currentOptionsProperty = [Sentry.SentrySdk].GetProperty('CurrentOptions', $bindingFlags)
        if ($null -eq $currentOptionsProperty)
        {
            return $null
        }

        [Sentry.SentryOptions] $options = $currentOptionsProperty.GetValue($null)
        $options.AttachStacktrace = $false
        try
        {
            FuncA 'pass' 'message'
            $events.Count | Should -Be 1
            [Sentry.SentryEvent]$event = $events.ToArray()[0]
            $event.SentryExceptions | Should -Be @()
            $event.Message.Message | Should -Be 'message'
            $event.SentryThreads.Count | Should -Be 1
            $event.SentryThreads[0].Stacktrace.Frames.Count | Should -Be 0
        }
        finally
        {
            $options.AttachStacktrace = $true
        }
    }

    It 'does not add stack trace to error when AttachStacktrace=false' {
        $bindingFlags = [System.Reflection.BindingFlags]::Static + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public
        $currentOptionsProperty = [Sentry.SentrySdk].GetProperty('CurrentOptions', $bindingFlags)
        if ($null -eq $currentOptionsProperty)
        {
            return $null
        }

        [Sentry.SentryOptions] $options = $currentOptionsProperty.GetValue($null)
        $options.AttachStacktrace = $false
        try
        {

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

            $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
            $event.SentryExceptions[0].Value | Should -Be 'error'
            $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
            $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty

            $event.SentryThreads.Count | Should -Be 1
            $event.SentryThreads[0].Stacktrace.Frames.Count | Should -Be 0
        }
        finally
        {
            $options.AttachStacktrace = $true
        }
    }
}

Describe 'Invoke-WithSentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures error record' {
        try
        {
            Invoke-WithSentry { funcA 'throw' 'error' }
        }
        catch {}

        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        @($null) | ForEach-Object $checkErrorRecord
    }
}
