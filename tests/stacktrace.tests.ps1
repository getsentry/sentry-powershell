BeforeAll {
    . "$PSScriptRoot/utils.ps1"
    . "$PSScriptRoot/throwing.ps1"
    . "$PSScriptRoot/throwingshort.ps1"
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    $transport = [RecordingTransport]::new()
    StartSentryForEventTests ([ref] $events) ([ref] $transport)

    function ContextLines($start, $lines, $path = $null) {
        if ($null -eq $path) {
            $path = "$PSScriptRoot/throwing.ps1"
        }

        Get-Content $path | Select-Object -Skip ($start - 1) -First $lines
    }

    $checkFrame = {
        param([Sentry.SentryStackFrame] $frame, [string] $funcName, [int] $funcLine)
        $frame.Function | Should -Be $funcName
        $frame.AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'throwing.ps1')
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

        $event.SentryExceptions[1].Type | Should -Match 'error|error,funcB|write-error'
        $event.SentryExceptions[1].Value | Should -Be 'error'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0

        if ($event.SentryExceptions[1].Type -eq 'Write-Error') {
            $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 15)
            $event.SentryExceptions[0].Type | Should -Be 'Microsoft.PowerShell.Commands.WriteErrorException'
            $event.SentryExceptions[0].Module | Should -Match 'Microsoft.PowerShell.Commands.Utility'
        } else {
            if ($event.SentryExceptions[1].Type -eq 'error') {
                $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 14)
                $(GetListItem $frames -1).ColumnNumber | Should -BeGreaterThan 0
            } else {
                $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 19)
            }
            $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
            $event.SentryExceptions[0].Module | Should -Match 'System.Management.Automation'
        }

        $checkFrame.Invoke((GetListItem $frames -2), 'funcA', 6)

        $event.SentryExceptions[0].Value | Should -Be 'error'
        if ($event.SentryExceptions[1].Type -eq 'error,funcB') {
            $event.SentryExceptions[0].Stacktrace.Frames[0].Function | Should -Be 'void MshCommandRuntime.ThrowTerminatingError(ErrorRecord errorRecord)'
            $event.SentryThreads.Count | Should -Be 1
        } else {
            $event.SentryExceptions[0].Stacktrace | Should -BeNullOrEmpty
            $event.SentryThreads.Count | Should -Be 2
        }

        $event.SentryThreads[0].Stacktrace.Frames | Should -BeExactly $frames

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }

    $checkShortErrorRecord = {
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[1].Type | Should -Be 'Short context test'
        $event.SentryExceptions[1].Value | Should -Be 'Short context test'
        $event.SentryExceptions[1].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[1].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 1

        $frame = GetListItem $frames -1

        $frame.Function | Should -Be 'funcC'
        $frame.AbsolutePath | Should -Be (Join-Path $PSScriptRoot 'throwingshort.ps1')
        $frame.LineNumber | Should -BeGreaterThan 0
        $frame.InApp | Should -Be $true

        $frame.PreContext | Should -Be @('function funcC {')
        $frame.PreContext.Count | Should -Be 1
        $frame.ContextLine | Should -Be "    throw 'Short context test'"
        $frame.PostContext | Should -Be @('}')
        $frame.PostContext.Count | Should -Be 1
    }
    $global:SentryPowershellRethrowErrors = $true
}

AfterAll {
    $global:SentryPowershellRethrowErrors = $false
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
        $checkFrame.Invoke((GetListItem $frames -1), 'funcB', 16)
        $checkFrame.Invoke((GetListItem $frames -2), 'funcA', 6)

        # A module-based frame should be in-app=false
        $frames | Where-Object -Property Module | Select-Object -First 1 -ExpandProperty 'InApp' | Should -Be $false
    }

    It 'captures error record' {
        try {
            funcA 'throw' 'error'
        } catch {
            $_ | Out-Sentry
        }

        @($null) | ForEach-Object $checkErrorRecord
    }

    It 'captures short context' {
        try {
            funcC
        } catch {
            $_ | Out-Sentry
        }

        @($null) | ForEach-Object $checkShortErrorRecord
    }

    It 'captures exception' {
        try {
            funcA 'throw' 'exception'
        } catch {
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
        (GetListItem $frames -1).PreContext | Should -Be @('', "    It 'captures exception' {", '        try {', "            funcA 'throw' 'exception'", '        } catch {')
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
        if ($null -eq $currentOptionsProperty) {
            return $null
        }

        [Sentry.SentryOptions] $options = $currentOptionsProperty.GetValue($null)
        $options.AttachStacktrace = $false
        try {
            FuncA 'pass' 'message'
            $events.Count | Should -Be 1
            [Sentry.SentryEvent]$event = $events.ToArray()[0]
            $event.SentryExceptions | Should -Be @()
            $event.Message.Message | Should -Be 'message'
            $event.SentryThreads.Count | Should -Be 1
            $event.SentryThreads[0].Stacktrace.Frames.Count | Should -Be 0
        } finally {
            $options.AttachStacktrace = $true
        }
    }

    It 'does not add stack trace to error when AttachStacktrace=false' {
        $bindingFlags = [System.Reflection.BindingFlags]::Static + [System.Reflection.BindingFlags]::NonPublic + [System.Reflection.BindingFlags]::Public
        $currentOptionsProperty = [Sentry.SentrySdk].GetProperty('CurrentOptions', $bindingFlags)
        if ($null -eq $currentOptionsProperty) {
            return $null
        }

        [Sentry.SentryOptions] $options = $currentOptionsProperty.GetValue($null)
        $options.AttachStacktrace = $false
        try {

            try {
                funcA 'throw' 'error'
            } catch {
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
        } finally {
            $options.AttachStacktrace = $true
        }
    }
}

Describe 'Invoke-WithSentry' {
    AfterEach {
        $events.Clear()
    }

    It 'captures error record' {
        try {
            Invoke-WithSentry { funcA 'throw' 'error' }
        } catch {}

        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        @($null) | ForEach-Object $checkErrorRecord
    }
}

Describe 'trap' {
    BeforeEach {
        $eap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
    }
    AfterEach {
        $events.Clear()
        $ErrorActionPreference = $eap
    }

    It 'gets triggered by throw' {
        $info = @{'triggers' = 0 }

        # We need to have Trap inside another function because it lets the function continue and as such, it would also
        # override any test failures so the test would show up as passed.
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_trap?view=powershell-7.4#trapping-errors-and-scope
        function TestFunction {
            trap {
                $_ | Out-Sentry
                $info['triggers'] = $info['triggers'] + 1
            }

            funcA 'throw' 'error'
        }

        TestFunction
        @($null) | ForEach-Object $checkErrorRecord
        $info['triggers'] | Should -Be 1

        # and because the execution continues, the same trap must work again:
        $events.Clear()
        TestFunction
        @($null) | ForEach-Object $checkErrorRecord
        $info['triggers'] | Should -Be 2
    }

    It 'gets triggered by a Write-Error' {
        $info = @{'triggers' = 0 }

        # We need to have Trap inside another function because it lets the function continue and as such, it would also
        # override any test failures so the test would show up as passed.
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_trap?view=powershell-7.4#trapping-errors-and-scope
        function TestFunction {
            trap {
                $_ | Out-Sentry
                $info['triggers'] = $info['triggers'] + 1
            }

            funcA 'write' 'error' -ErrorAction Stop
        }

        TestFunction
        @($null) | ForEach-Object $checkErrorRecord
        $info['triggers'] | Should -Be 1

        # and because the execution continues, the same trap must work again:
        $events.Clear()
        TestFunction
        @($null) | ForEach-Object $checkErrorRecord
        $info['triggers'] | Should -Be 2
    }

    It 'gets triggered by ThrowTerminatingError' {
        $info = @{'triggers' = 0 }

        # We need to have Trap inside another function because it lets the function continue and as such, it would also
        # override any test failures so the test would show up as passed.
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_trap?view=powershell-7.4#trapping-errors-and-scope
        function TestFunction {
            trap {
                $_ | Out-Sentry
                $info['triggers'] = $info['triggers'] + 1
            }

            funcA 'pipeline' 'error' -ErrorAction Stop
        }

        TestFunction
        @($null) | ForEach-Object $checkErrorRecord

        # and because the execution continues, the same trap must work again:
        $events.Clear()
        TestFunction
        @($null) | ForEach-Object $checkErrorRecord
        $info['triggers'] | Should -Be 2
    }
}
