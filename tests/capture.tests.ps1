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

class EventEnricher:Sentry.Extensibility.ISentryEventProcessor
{
    [Sentry.Protocol.SentryException]$SentryException
    [System.Management.Automation.InvocationInfo]$InvocationInfo
    [System.Management.Automation.CallStackFrame[]]$StackTraceFrames
    [string[]] $modulePaths = $env:PSModulePath.Split(';')

    [Sentry.SentryEvent]Process([Sentry.SentryEvent] $event_)
    {
        try
        {
            if ($null -ne $this.SentryException)
            {
                $this.ProcessException($event_)
            }
            elseif ($null -ne $event_.Message)
            {
                $this.ProcessMessage($event_)
            }
        }
        catch
        {
            $ErrorRecord = $_
            ("$([EventEnricher]) failed to enrich event $($event_.EventId):" `
                && $ErrorRecord | Format-List * -Force | Out-String `
                && $ErrorRecord.InvocationInfo | Format-List * | Out-String `
                && $ErrorRecord.Exception | Format-List * -Force | Out-String) `
            | Write-Warning
        }

        return $event_
    }

    hidden ProcessException([Sentry.SentryEvent] $event_)
    {
        if ($null -ne $this.StackTraceFrames)
        {
            $this.SentryException.Stacktrace = $this.GetStackTrace()
            if ($this.SentryException.Stacktrace.Frames.Count -gt 0 -and $null -ne $this.SentryException.Stacktrace.Frames[0].Module)
            {
                $this.SentryException.Module = $this.SentryException.Stacktrace.Frames[0].Module
            }
        }

        # Add the c# exception to the front of the exception list, followed by whatever is already there.
        $newExceptions = New-Object System.Collections.Generic.List[Sentry.Protocol.SentryException]
        $newExceptions.Add($this.SentryException)
        if ($null -ne $event_.SentryExceptions)
        {
            foreach ($e in $event_.SentryExceptions)
            {
                if ($null -eq $e.Mechanism)
                {
                    $e.Mechanism = [Sentry.Protocol.Mechanism]::new()
                }
                $e.Mechanism.Synthetic = $true
                $newExceptions.Add($e)
            }
        }
        $event_.SentryExceptions = $newExceptions
    }

    hidden ProcessMessage([Sentry.SentryEvent] $event_)
    {
        # TODO
        # $sentryStackTrae = $this.GetStackTrace()
        # Write-Host 'done'
    }

    hidden [Sentry.SentryStackTrace]GetStackTrace()
    {
        # We collect all frames and then reverse them to the order expected by Sentry (caller->callee).
        # Do not try to make this code go backwards, because it relies on the InvocationInfo from the previous frame.
        $sentryFrames = New-Object System.Collections.Generic.List[Sentry.SentryStackFrame] $this.StackTraceFrames.Count

        # Note: if InvocationInfo is present, use it to fill the first frame. This is the case for ErrroRecord handling
        # and has the information about the actual script file and line that have thrown the exception.
        if ($null -ne $this.InvocationInfo)
        {
            $sentryFrames.Add($this.CreateFrame($this.InvocationInfo))
        }

        foreach ($frame in $this.StackTraceFrames)
        {
            $sentryFrames.Add($this.CreateFrame($frame))
        }

        foreach ($sentryFrame in $sentryFrames)
        {
            # Update module info
            $this.SetModule($sentryFrame)
            $sentryFrame.InApp = $null -eq $sentryFrame.Module
            $this.SetContextLines($sentryFrame)
        }

        $sentryFrames.Reverse()
        $stacktrace_ = [Sentry.SentryStackTrace]::new()
        $stacktrace_.Frames = $sentryFrames
        return $stacktrace_
    }

    hidden [Sentry.SentryStackFrame] CreateFrame([System.Management.Automation.InvocationInfo] $info)
    {
        $sentryFrame = [Sentry.SentryStackFrame]::new()
        $sentryFrame.AbsolutePath = $info.ScriptName
        $sentryFrame.LineNumber = $info.ScriptLineNumber
        $sentryFrame.ColumnNumber = $info.OffsetInLine
        $sentryFrame.ContextLine = $info.Line.TrimEnd()
        return $sentryFrame
    }

    hidden [Sentry.SentryStackFrame] CreateFrame([System.Management.Automation.CallStackFrame] $frame)
    {
        $sentryFrame = [Sentry.SentryStackFrame]::new()
        $this.SetScriptInfo($sentryFrame, $frame)
        $this.SetModule($sentryFrame)
        $this.SetFunction($sentryFrame, $frame)
        $sentryFrame.InApp = $null -eq $sentryFrame.Module
        return $sentryFrame
    }

    hidden SetScriptInfo([Sentry.SentryStackFrame] $sentryFrame, [System.Management.Automation.CallStackFrame] $frame)
    {
        if ($null -ne $frame.ScriptName)
        {
            $sentryFrame.AbsolutePath = $frame.ScriptName
            $sentryFrame.LineNumber = $frame.ScriptLineNumber
        }
        elseif ($null -ne $frame.Position -and $null -ne $frame.Position.File)
        {
            $sentryFrame.AbsolutePath = $frame.Position.File
            $sentryFrame.LineNumber = $frame.Position.StartLineNumber
            $sentryFrame.ColumnNumber = $frame.Position.StartColumnNumber
        }
    }

    hidden SetModule([Sentry.SentryStackFrame] $sentryFrame)
    {
        if ($null -ne $sentryFrame.AbsolutePath)
        {
            if ($prefix = $this.modulePaths | Where-Object { $sentryFrame.AbsolutePath.StartsWith($_) })
            {
                $relativePath = $sentryFrame.AbsolutePath.Substring($prefix.Length + 1)
                $sentryFrame.Module = ($relativePath -split '[\\/]') | Select-Object -First 1
            }
        }
    }

    hidden SetFunction([Sentry.SentryStackFrame] $sentryFrame, [System.Management.Automation.CallStackFrame] $frame)
    {
        if ($null -eq $sentryFrame.AbsolutePath -and $frame.FunctionName -eq '<ScriptBlock>' -and $null -ne $frame.Position)
        {
            $sentryFrame.Function = $frame.Position.Text
        }
        else
        {
            $sentryFrame.Function = $frame.FunctionName
        }
    }

    hidden SetContextLines([Sentry.SentryStackFrame] $sentryFrame)
    {
        if ($null -ne $sentryFrame.AbsolutePath -and $sentryFrame.LineNumber -ge 1 -and (Test-Path $sentryFrame.AbsolutePath -PathType Leaf))
        {
            try
            {
                $lines = Get-Content $sentryFrame.AbsolutePath -TotalCount ($sentryFrame.LineNumber + 5)
                if ($null -eq $sentryFrame.ContextLine)
                {
                    $sentryFrame.ContextLine = $lines[$sentryFrame.LineNumber - 1]
                }
                if ($sentryFrame.LineNumber -gt 6)
                {
                    $lines = $lines | Select-Object -Skip ($sentryFrame.LineNumber - 6)
                }
                # TODO currently these are read-only in sentry-dotnet. We should change that.
                # $sentryFrame.PreContext = $lines | Select-Object -First 5
                # $sentryFrame.PostContext = $lines | Select-Object -Last 5
            }
            catch
            {
                Write-Warning "Failed to read context lines for $($sentryFrame.AbsolutePath): $_"
            }
        }
    }

}

function Out-Sentry2
{
    param(
        [Parameter(ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(ValueFromPipeline = $true)]
        [System.Exception]
        $Exception,

        [Parameter(ValueFromPipeline = $true)]
        [string]
        $Message
    )

    begin {}
    process
    {
        [Sentry.SentryEvent]$event_
        $processor = [EventEnricher]::new()

        if ($ErrorRecord -ne $null)
        {
            $event_ = [Sentry.SentryEvent]::new($ErrorRecord.Exception)
            $processor.InvocationInfo = $ErrorRecord.InvocationInfo
            $processor.SentryException = [Sentry.Protocol.SentryException]::new()
            $processor.SentryException.Type = $ErrorRecord.FullyQualifiedErrorId
            if ($details = $ErrorRecord.ErrorDetails -and $null -ne $details.Message)
            {
                $processor.SentryException.Value = $details.Message
            }
            else
            {
                $processor.SentryException.Value = $ErrorRecord.Exception.Message
            }


            # TODO parse $ErrorRecord.ScriptStackTrace
            # $processor.StackTraceFrames = @()
        }
        elseif ($Exception -ne $null -and ($Message -eq $null -or "$Exception" -eq "$Message"))
        {
            $event_ = [Sentry.SentryEvent]::new($Exception)
            $processor.SentryException = [Sentry.Protocol.SentryException]::new()
            $processor.SentryException.Type = $Exception.GetType().FullName
            $processor.SentryException.Value = $Exception.Message
        }
        elseif ($Message -ne $null)
        {
            $event_ = [Sentry.SentryEvent]::new($Exception)
            $event_.Message = $Message
            $event_.Level = [Sentry.SentryLevel]::Info
        }

        if ($null -eq $event_)
        {
            Write-Debug 'Out-Sentry: Nothing to capture'
            return
        }

        if ($null -eq $processor.StackTraceFrames)
        {
            $processor.StackTraceFrames = Get-PSCallStack | Select-Object -Skip 1
        }

        [Sentry.SentrySdk]::CaptureEvent($event_, [System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)
                [Sentry.ScopeExtensions]::AddEventProcessor($scope, $processor)
            })
    }
    end {}
}


function funcA($action, $param)
{
    funcB $action $param
}
function funcB($action, $param)
{
    if ($action -eq 'throw')
    {
        throw $param
    }
    else
    {
        $param | Out-Sentry2
    }
}

Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    # It 'captures message' {
    #     FuncA ' ' 'message'
    #     $events.Count | Should -Be 1
    #     [Sentry.SentryEvent]$event = $events.ToArray()[0]
    #     $event.Exception | Should -Be $null
    #     $event.Message.Message | Should -Be 'message'
    # }

    It 'captures error record' {
        try
        {
            funcA 'throw' 'error'
        }
        catch
        {
            $_ | Out-Sentry2
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.SentryExceptions.Count | Should -Be 2

        $event.SentryExceptions[0].Type | Should -Be 'error'
        $event.SentryExceptions[0].Value | Should -Be 'error'
        $event.SentryExceptions[0].Module | Should -BeNullOrEmpty
        [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[0].Stacktrace.Frames
        $frames.Count | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -BeNullOrEmpty # Todo, ideally this should be FuncB
        $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be $PSCommandPath
        $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
        $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '        throw $param'

        # TODO second frame should be of FuncB call in FuncA

        $event.SentryExceptions[1].Type | Should -Be 'System.Management.Automation.RuntimeException'
        $event.SentryExceptions[1].Value | Should -Be 'error'
        $event.SentryExceptions[1].Module | Should -Match 'System.Management.Automation'
        $event.SentryExceptions[1].Stacktrace.Frames.Count | Should -Be 0

        $event.SentryThreads.Count | Should -Be 1
        $event.SentryThreads[0].Stacktrace.Frames.Count | Should -BeGreaterThan 0
    }

    # It 'captures exception' {
    #     try
    #     {
    #         funcA 'throw' 'exception'
    #     }
    #     catch
    #     {
    #         $_.Exception | Out-Sentry2
    #     }
    #     $events.Count | Should -Be 1
    #     [Sentry.SentryEvent]$event = $events.ToArray()[0]
    #     $event.SentryExceptions.Count | Should -Be 2

    #     $event.SentryExceptions[0].Type | Should -Be 'System.Management.Automation.RuntimeException'
    #     $event.SentryExceptions[0].Value | Should -Be 'exception'
    #     $event.SentryExceptions[0].Module | Should -BeNullOrEmpty
    #     [Sentry.SentryStackFrame[]] $frames = $event.SentryExceptions[0].Stacktrace.Frames
    #     $frames.Count | Should -BeGreaterThan 0
    #     $frames | Select-Object -Last 1 -ExpandProperty 'Function' | Should -Be '<ScriptBlock>'
    #     $frames | Select-Object -Last 1 -ExpandProperty 'AbsolutePath' | Should -Be $PSCommandPath
    #     $frames | Select-Object -Last 1 -ExpandProperty 'LineNumber' | Should -BeGreaterThan 0
    #     $frames | Select-Object -Last 1 -ExpandProperty 'ContextLine' | Should -Be '            $_.Exception | Out-Sentry2'

    #     $event.SentryExceptions[1].Type | Should -Be 'System.Management.Automation.RuntimeException'
    #     $event.SentryExceptions[1].Value | Should -Be 'exception'
    #     $event.SentryExceptions[1].Module | Should -Match 'System.Management.Automation'
    #     $event.SentryExceptions[1].Stacktrace.Frames.Count | Should -Be 0

    #     $event.SentryThreads.Count | Should -Be 1
    #     $event.SentryThreads[0].Stacktrace.Frames.Count | Should -BeGreaterThan 0
    # }
}

# Describe 'Invoke-WithSentry' {
#     AfterEach {
#         $events.Clear()
#     }

#     It 'captures error record' {
#         try
#         {
#             Invoke-WithSentry { throw 'inside invoke' }
#         }
#         catch {}
#         $events.Count | Should -Be 1
#         [Sentry.SentryEvent]$event = $events.ToArray()[0]
#         $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
#         $event.Exception.Message | Should -Be 'inside invoke'
#     }
# }
