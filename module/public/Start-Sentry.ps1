. "$privateDir/ScopeIntegration.ps1"
. "$privateDir/EventUpdater.ps1"

function Start-Sentry
{
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Simple', Position = 0)]
        [Uri] $Dsn,

        [Parameter(Mandatory, ParameterSetName = 'Options', Position = 0)]
        [scriptblock] $OptionsSetup
    )

    begin
    {
        $options = [Sentry.SentryOptions]::new()
        $options.ReportAssembliesMode = [Sentry.ReportAssembliesMode]::None
        $options.IsGlobalModeEnabled = $true
        [Sentry.sentryOptionsExtensions]::AddIntegration($options, [ScopeIntegration]::new())
        [Sentry.sentryOptionsExtensions]::AddEventProcessor($options, [EventUpdater]::new())

        if ($DebugPreference -ne 'SilentlyContinue')
        {
            $Options.Debug = $true
        }

        if ($OptionsSetup -eq $null)
        {
            $options.Dsn = $Dsn
        }
        else
        {
            # Execute the script block in the caller's scope & set the automatic $_ variable to the options object.
            $options | ForEach-Object $OptionsSetup
        }
    }
    process
    {
        [Sentry.SentrySdk]::init($options) | Out-Null
    }
}
