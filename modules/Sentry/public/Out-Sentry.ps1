. "$privateDir/StackTraceProcessor.ps1"
. "$privateDir/Get-CurrentOptions.ps1"

function Out-Sentry {
    [OutputType([Sentry.SentryId])]
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
        $Message,

        [Parameter(ParameterSetName = 'ErrorRecord')]
        [Parameter(ParameterSetName = 'Exception')]
        [Parameter(ParameterSetName = 'Message')]
        [scriptblock] $EditScope
    )

    begin {}
    process {
        if (-not [Sentry.SentrySdk]::IsEnabled) {
            # Workaround for:
            #   NullReferenceException: Object reference not set to an instance of an object.
            # at Out-Sentry<Process>, D:\a\sentry-powershell\sentry-powershell\modules\Sentry\public\Out-Sentry.ps1:32
            try {
                Write-Debug 'Sentry is not started: Out-Sentry invocation ignored.'
            } catch {}
            return
        }

        $options = Get-CurrentOptions
        [Sentry.SentryEvent]$event_ = $null
        $processor = [StackTraceProcessor]::new($options)

        if ($ErrorRecord -ne $null) {
            $event_ = [Sentry.SentryEvent]::new($ErrorRecord.Exception)
            $processor.SentryException = [Sentry.Protocol.SentryException]::new()

            if ($($ErrorRecord.CategoryInfo.Activity) -eq 'Write-Error') {
                # FullyQualifiedErrorId would be "Microsoft.PowerShell.Commands.WriteErrorException,funcB"
                $processor.SentryException.Type = 'Write-Error'
            } else {
                $processor.SentryException.Type = $ErrorRecord.FullyQualifiedErrorId
            }

            if (($details = $ErrorRecord.ErrorDetails) -and $null -ne $details.Message) {
                $processor.SentryException.Value = $details.Message
            } else {
                $processor.SentryException.Value = $ErrorRecord.Exception.Message
            }

            if ($options.AttachStackTrace) {
                # Note: we use ScriptStackTrace even though we need to parse it, becaause it contains actual stack trace
                # to the throw, not just the trace to the call to this function.
                $processor.StackTraceString = @($ErrorRecord.ScriptStackTrace -split "[`r`n]+")
                $processor.InvocationInfo = $ErrorRecord.InvocationInfo
            }

        } elseif ($Exception -ne $null) {
            $event_ = [Sentry.SentryEvent]::new($Exception)
            $processor.SentryException = [Sentry.Protocol.SentryException]::new()
            $processor.SentryException.Type = $Exception.GetType().FullName
            $processor.SentryException.Value = $Exception.Message
        } elseif ($Message -ne $null) {
            $event_ = [Sentry.SentryEvent]::new()
            $event_.Message = $Message
            $event_.Level = [Sentry.SentryLevel]::Info
        } else {
            Write-Warning 'Out-Sentry: No argument matched, nothing to do'
            return
        }

        if ($null -eq $event_) {
            Write-Debug 'Out-Sentry: Nothing to capture'
            return
        }

        if ($options.AttachStackTrace -and $null -eq $processor.StackTraceFrames) {
            $processor.StackTraceFrames = Get-PSCallStack | Select-Object -Skip 1
        }

        return [Sentry.SentrySdk]::CaptureEvent($event_, [System.Action[Sentry.Scope]] {
                param([Sentry.Scope]$scope)
                $scope.AddEventProcessor($processor)

                # Execute the script block in the caller's scope (nothing to do $scope) & set the automatic $_ variable to the $scope object.
                $scope | ForEach-Object $EditScope
            })
    }
}
