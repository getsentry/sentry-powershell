. "$privateDir/StackTraceProcessor.ps1"
. "$privateDir/Get-CurrentOptions.ps1"

function Out-Sentry
{
    [CmdletBinding(DefaultParameterSetName = 'ErrorRecord')]
    param(
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [string]
        $Message
    )

    begin {}
    process
    {
        if (-not [Sentry.SentrySdk]::IsEnabled)
        {
            Write-Debug 'Out-Sentry: Sentry is not enabled, skipping'
            return
        }

        $options = Get-CurrentOptions
        [Sentry.SentryEvent]$event_
        $processor = [StackTraceProcessor]::new()

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

            if ($options.AttachStackTrace)
            {
                # Note: we use ScriptStackTrace even though we need to parse it, becaause it contains actual stack trace
                # to the throw, not just the trace to the call to this function.
                $processor.StackTraceString = $ErrorRecord.ScriptStackTrace -split "[`r`n]+" | Where-Object { $_ -ne 'at <ScriptBlock>, <No file>: line 1' }
            }

        }
        elseif ($Exception -ne $null)
        {
            $event_ = [Sentry.SentryEvent]::new($Exception)
            $processor.SentryException = [Sentry.Protocol.SentryException]::new()
            $processor.SentryException.Type = $Exception.GetType().FullName
            $processor.SentryException.Value = $Exception.Message
        }
        elseif ($Message -ne $null)
        {
            $event_ = [Sentry.SentryEvent]::new()
            $event_.Message = $Message
            $event_.Level = [Sentry.SentryLevel]::Info
        }
        else
        {
            Write-Warning 'Out-Sentry: No argument matched, nothing to do'
            return
        }

        if ($null -eq $event_)
        {
            Write-Debug 'Out-Sentry: Nothing to capture'
            return
        }

        if ($options.AttachStackTrace -and $null -eq $processor.StackTraceFrames -and $null -eq $processor.StackTraceString)
        {
            $processor.StackTraceFrames = Get-PSCallStack | Select-Object -Skip 1
        }

        return [Sentry.SentrySdk]::CaptureEvent($event_, [System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)
                [Sentry.ScopeExtensions]::AddEventProcessor($scope, $processor)
            })
    }
    end {}
}
