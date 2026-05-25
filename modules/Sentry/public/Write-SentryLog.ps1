function Write-SentryLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string] $Message,

        [Sentry.SentryLogLevel] $Level = [Sentry.SentryLogLevel]::Info,

        [object[]] $Parameters,

        [hashtable] $Attributes
    )

    process {
        if (-not [Sentry.SentrySdk]::IsEnabled) {
            try {
                Write-Debug 'Sentry is not started: Write-SentryLog invocation ignored.'
            } catch {}
            return
        }

        $values = if ($null -eq $Parameters) { [object[]]@() } else { [object[]]$Parameters }
        $methodName = "Log$Level"

        if ($null -ne $Attributes -and $Attributes.Count -gt 0) {
            $configureLog = [System.Action[Sentry.SentryLog]] {
                param([Sentry.SentryLog]$log)
                foreach ($key in $Attributes.Keys) {
                    $log.SetAttribute([string]$key, $Attributes[$key])
                }
            }
            [Sentry.SentrySdk]::Logger.$methodName($configureLog, $Message, $values)
        } else {
            [Sentry.SentrySdk]::Logger.$methodName($Message, $values)
        }
    }
}
