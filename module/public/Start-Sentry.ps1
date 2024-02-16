function Start-Sentry
{
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Simple', Position = 0)]
        [Uri] $Dsn,

        [Parameter(Mandatory, ParameterSetName = 'Options', Position = 0)]
        [Sentry.SentryOptions] $Options
    )

    begin
    {
        if ($Options -eq $null)
        {
            $Options = [Sentry.SentryOptions]::new()
            $Options.Dsn = $Dsn
        }

        if ($DebugPreference -eq 'Continue')
        {
            $Options.Debug = $true
        }
    }
    process
    {
        [Sentry.SentrySdk]::init($options)
    }
}
