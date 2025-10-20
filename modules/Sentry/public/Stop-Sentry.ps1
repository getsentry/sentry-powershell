function Stop-Sentry {
    [Sentry.SentrySdk]::Close()
    Remove-Variable -Scope script -Name SentryPowerShellDiagnosticLogger -ErrorAction SilentlyContinue
}
