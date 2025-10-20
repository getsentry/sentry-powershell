. "$privateDir/DiagnosticLogger.ps1"
. "$privateDir/ScopeIntegration.ps1"
. "$privateDir/SynchronousWorker.ps1"
. "$privateDir/SynchronousTransport.ps1"
. "$privateDir/EventUpdater.ps1"

function Start-Sentry {
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Simple', Position = 0)]
        [Uri] $Dsn,

        [Parameter(Mandatory, ParameterSetName = 'Options', Position = 0)]
        [scriptblock] $EditOptions
    )

    begin {
        $options = [Sentry.SentryOptions]::new()
        $options.FlushTimeout = [System.TimeSpan]::FromSeconds(10)
        $options.ShutDownTimeout = $options.FlushTimeout
        $options.ReportAssembliesMode = [Sentry.ReportAssembliesMode]::None
        $options.IsGlobalModeEnabled = $true
        $options.AddIntegration([ScopeIntegration]::new())
        $options.AddEventProcessor([EventUpdater]::new())

        if ($DebugPreference -eq 'SilentlyContinue') {
            $Options.Debug = $false
            $options.DiagnosticLevel = [Sentry.SentryLevel]::Info
        } else {
            $Options.Debug = $true
            $options.DiagnosticLevel = [Sentry.SentryLevel]::Debug
        }

        if ($EditOptions -eq $null) {
            $options.Dsn = $Dsn
        } else {
            # Execute the script block in the caller's scope & set the automatic $_ variable to the options object.
            $options | ForEach-Object $EditOptions
        }

        $logger = [DiagnosticLogger]::new($options.DiagnosticLevel)

        # Note: this is currently a no-op if options.debug == false; see https://github.com/getsentry/sentry-dotnet/issues/3212
        # As a workaround, we set the logger as a global variable so that we can reach it in other scripts.
        $options.DiagnosticLogger = $logger
        $script:SentryPowerShellDiagnosticLogger = $logger

        if ($null -eq $options.Transport) {
            try {
                $options.Transport = [SynchronousTransport]::new($options)
            } catch {
                $logger.Log([Sentry.SentryLevel]::Warning, 'Failed to create a PowerShell-specific synchronous transport', $_.Exception, @())
                if ($global:SentryPowershellRethrowErrors -eq $true) {
                    throw
                }
            }
        }

        if ($null -eq $options.BackgroundWorker) {
            try {
                $options.BackgroundWorker = [SynchronousWorker]::new($options)
            } catch {
                $logger.Log([Sentry.SentryLevel]::Warning, 'Failed to create a PowerShell-specific synchronous worker', $_.Exception, @())
                if ($global:SentryPowershellRethrowErrors -eq $true) {
                    throw
                }
            }
        }
    }
    process {
        [Sentry.SentrySdk]::init($options) | Out-Null
    }
}
