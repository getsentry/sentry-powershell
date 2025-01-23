function Stop-Sentry
{
    [Sentry.SentrySdk]::Close()
    Remove-Variable -Scope global -Name SentryPowerShellDiagnosticLogger
}
