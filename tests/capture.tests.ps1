BeforeAll {
    $events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
    $options = [Sentry.SentryOptions]::new()
    $options.Debug = $true
    $options.Dsn = 'https://key@127.0.0.1/1'
    $options.AutoSessionTracking = $false
    $options.SetBeforeSend([System.Func[Sentry.SentryEvent, Sentry.SentryEvent]] {
            param([Sentry.SentryEvent]$e)
            $events.Add($e)
            return $null # Prevent sending
        });
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
            if ($null -ne $this.SentryException -and $null -ne $this.StackTraceFrames)
            {
                $this.SentryException.Stacktrace = $this.GetStackTrace()
                $this.SentryException.Module = $this.SentryException.Stacktrace.Frames | Select-Object -First 1 -Property 'Module'

                # Add the c# exception to the front of the exception list, followed by whatever is already there.
                $newExceptions = New-Object System.Collections.Generic.List[Sentry.Protocol.SentryException]
                $newExceptions.Add($this.SentryException)
                if ($null -ne $event_.SentryExceptions)
                {
                    $event_.SentryExceptions | ForEach-Object {
                        if ($null -eq $_.Mechanism)
                        {
                            $_.Mechanism = [Sentry.Protocol.Mechanism]::new()
                        }
                        $_.Mechanism.Synthetic = $true
                        $newExceptions.Add($_)
                    }
                }
                $event_.SentryExceptions = $newExceptions
                Write-Host 'done'
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

    hidden [Sentry.SentryStackTrace]GetStackTrace()
    {
        # We collect all frames and then reverse them to the order expected by Sentry (caller->callee).
        # Do not try to make this code go backwards, because it relies on the InvocationInfo from the previous frame.
        $sentryFrames = New-Object System.Collections.Generic.List[Sentry.SentryStackFrame] $this.StackTraceFrames.Count
        $invocInfo = $this.InvocationInfo

        foreach ($frame in $this.StackTraceFrames)
        {
            $sentryFrame = [Sentry.SentryStackFrame]::new()
            $this.SetScriptInfo($sentryFrame, $frame)
            $this.SetModule($sentryFrame)
            $this.SetFunction($sentryFrame, $frame)
            $sentryFrame.InApp = $null -eq $sentryFrame.Module

            $sentryFrames.Add($sentryFrame)
            $invocInfo = $frame.InvocationInfo
        }

        $sentryFrames.Reverse()
        $stacktrace_ = [Sentry.SentryStackTrace]::new()
        $stacktrace_.Frames = $sentryFrames
        return $stacktrace_
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
            $processor.SentryException.Value = $ErrorRecord.Exception.Message

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

        $event_.Platform = 'Sentry.PowerShell'
        [Sentry.SentrySdk]::CaptureEvent($event_, [System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)
                [Sentry.ScopeExtensions]::AddEventProcessor($scope, $processor)
            })
    }
    end {}
}

Describe 'Out-Sentry' {
    AfterEach {
        $events.Clear()
    }

    # It 'captures message' {
    #     'message' | Out-Sentry
    #     $events.Count | Should -Be 1
    #     [Sentry.SentryEvent]$event = $events.ToArray()[0]
    #     $event.Exception | Should -Be $null
    #     $event.Message.Message | Should -Be 'message'
    # }

    It 'captures error record' {
        try
        {
            throw 'error'
        }
        catch
        {
            $_ | Out-Sentry2
        }
        $events.Count | Should -Be 1
        [Sentry.SentryEvent]$event = $events.ToArray()[0]
        $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
        $event.Exception.Message | Should -Be 'error'
    }

    # It 'captures exception' {
    #     try
    #     {
    #         throw 'exception'
    #     }
    #     catch
    #     {
    #         $_.Exception | Out-Sentry
    #     }
    #     $events.Count | Should -Be 1
    #     [Sentry.SentryEvent]$event = $events.ToArray()[0]
    #     $event.Exception | Should -BeOfType [System.Management.Automation.RuntimeException]
    #     $event.Exception.Message | Should -Be 'exception'
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
