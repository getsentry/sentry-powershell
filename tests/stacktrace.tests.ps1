BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    $transport = [RecordingTransport]::new()
    StartSentryForEventTests ([ref] $events) ([ref] $transport)
}

AfterAll {
    Stop-Sentry
}

Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures message' {
        FuncA ' ' 'message'
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions | Should -Be @()

        $event.Message.Message | Should -Be 'message'

        $event.SentryThreads.Count | Should -Be 2
        [Sentry.SentryStackFrame[]] $frames = $event.SentryThreads[0].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        (GetListItem $frames -1).Function | Should -Be 'funcB'
        (GetListItem $frames -1).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -1).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).InApp | Should -Be $true
        (GetListItem $frames -1).PreContext | Should -Be @('    {', '        throw $param', '    }', '    else', '    {')
        (GetListItem $frames -1).ContextLine | Should -Be '        $param | Out-Sentry'
        (GetListItem $frames -1).PostContext | Should -Be @('    }', '}', '', 'function StartSentryForEventTests([ref] $events, [ref] $transport)', '{')

        (GetListItem $frames -2).Function | Should -Be 'funcA'
        (GetListItem $frames -2).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -2).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -2).InApp | Should -Be $true
        (GetListItem $frames -2).PreContext | Should -Be @('    }', '}', '', 'function funcA($action, $param)', '{')
        (GetListItem $frames -2).ContextLine | Should -Be '    funcB $action $param'
        (GetListItem $frames -2).PostContext | Should -Be @('}', '', 'function funcB($action, $param)', '{', "    if (`$action -eq 'throw')")

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
        (GetListItem $frames -1).Function | Should -Be 'funcB'
        (GetListItem $frames -1).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -1).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).ColumnNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).InApp | Should -Be $true
        (GetListItem $frames -1).PreContext | Should -Be @('', 'function funcB($action, $param)', '{', "    if (`$action -eq 'throw')", '    {')
        (GetListItem $frames -1).ContextLine | Should -Be '        throw $param'
        (GetListItem $frames -1).PostContext | Should -Be @('    }', '    else', '    {', '        $param | Out-Sentry', '    }')

        (GetListItem $frames -2).Function | Should -Be 'funcA'
        (GetListItem $frames -2).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -2).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -2).InApp | Should -Be $true
        (GetListItem $frames -2).PreContext | Should -Be @('    }', '}', '', 'function funcA($action, $param)', '{')
        (GetListItem $frames -2).ContextLine | Should -Be '    funcB $action $param'
        (GetListItem $frames -2).PostContext | Should -Be @('}', '', 'function funcB($action, $param)', '{', "    if (`$action -eq 'throw')")

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
            FuncA ' ' 'message'
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
        (GetListItem $frames -1).Function | Should -Be 'funcB'
        (GetListItem $frames -1).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -1).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).ColumnNumber | Should -BeGreaterThan 0
        (GetListItem $frames -1).InApp | Should -Be $true
        (GetListItem $frames -1).PreContext | Should -Be @('', 'function funcB($action, $param)', '{', "    if (`$action -eq 'throw')", '    {')
        (GetListItem $frames -1).ContextLine | Should -Be '        throw $param'
        (GetListItem $frames -1).PostContext | Should -Be @('    }', '    else', '    {', '        $param | Out-Sentry', '    }')

        (GetListItem $frames -2).Function | Should -Be 'funcA'
        (GetListItem $frames -2).AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'utils.ps1')
        (GetListItem $frames -2).LineNumber | Should -BeGreaterThan 0
        (GetListItem $frames -2).InApp | Should -Be $true
        (GetListItem $frames -2).PreContext | Should -Be @('    }', '}', '', 'function funcA($action, $param)', '{')
        (GetListItem $frames -2).ContextLine | Should -Be '    funcB $action $param'
        (GetListItem $frames -2).PostContext | Should -Be @('}', '', 'function funcB($action, $param)', '{', "    if (`$action -eq 'throw')")

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
