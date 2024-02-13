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

class EventStackTraceEnricher:Sentry.Extensibility.ISentryEventProcessor
{
    [System.Management.Automation.InvocationInfo]$InvocationInfo
    [System.Management.Automation.CallStackFrame[]]$StackTraceFrames

    [Sentry.SentryEvent]Process([Sentry.SentryEvent] $event_)
    {
        if ($null -ne $event_.SentryExceptions -and $event_.SentryExceptions.Count -gt 0)
        {
            [Sentry.Protocol.SentryException]$exception = $event_.SentryExceptions[0]
            if ($null -ne $this.StackTraceFrames)
            {
                $exception.Stacktrace = [Sentry.SentryStackTrace]::new()
                for ($i = $this.StackTraceFrames.Count - 1; $i -ge 0; $i--)
                {
                    $frame = $this.StackTraceFrames[$i]
                    $sentryFrame = [Sentry.SentryStackFrame]::new()
                    # TODO
                    # $sentryFrame. = $frame.
                    $exception.Stacktrace.Frames.Add($sentryFrame)
                }
            }
        }

        return $event_
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
        $processor = [EventStackTraceEnricher]::new()

        if ($ErrorRecord -ne $null)
        {
            $event_ = [Sentry.SentryEvent]::new($ErrorRecord.Exception)
            $processor.InvocationInfo = $ErrorRecord.InvocationInfo
            # TODO parse $ErrorRecord.ScriptStackTrace
            # $processor.StackTraceFrames = @()
        }
        elseif ($Exception -ne $null -and ($Message -eq $null -or "$Exception" -eq "$Message"))
        {
            $event_ = [Sentry.SentryEvent]::new($Exception)
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
