<#
.SYNOPSIS
    Demonstrates sending structured logs to Sentry from PowerShell.
.DESCRIPTION
    Shows how to enable Sentry Logs (https://docs.sentry.io/platforms/dotnet/logs/)
    in the PowerShell module and emit log messages at various severity levels,
    including templated messages with structured parameters.
.EXAMPLE
    PS> ./send-logs.ps1
.LINK
    https://docs.sentry.io/platforms/dotnet/logs/
#>

# Import the Sentry module. In your code, you would just use `Import-Module Sentry`.
Import-Module $PSScriptRoot/../modules/Sentry/Sentry.psd1

# Start the Sentry client. Set Experimental.EnableLogs = $true to opt in to Logs.
Start-Sentry {
    $_.Dsn = 'https://997874440feaba4ecc65c1e25df7912b@o447951.ingest.us.sentry.io/4508073336176640'
    $_.Debug = $true
    $_.Experimental.EnableLogs = $true
}

try {
    # The logger lives on SentrySdk. Each level maps to a separate method.
    [Sentry.SentrySdk]::Logger.LogTrace('Trace from PowerShell')
    [Sentry.SentrySdk]::Logger.LogDebug('Debug from PowerShell')
    [Sentry.SentrySdk]::Logger.LogInfo('Info from PowerShell')
    [Sentry.SentrySdk]::Logger.LogWarning('Warning from PowerShell')
    [Sentry.SentrySdk]::Logger.LogError('Error from PowerShell')
    [Sentry.SentrySdk]::Logger.LogFatal('Fatal from PowerShell')

    # Templated messages: placeholders in the template become structured
    # attributes on the log record, so you can search/filter on them in Sentry.
    $user = $env:USER ?? $env:USERNAME
    $host_ = [System.Net.Dns]::GetHostName()
    $psVersion = $PSVersionTable.PSVersion.ToString()
    # Templates use positional placeholders ({0}, {1}, ...) and the parameters are
    # captured as structured attributes on the log record so you can search/filter
    # on them in Sentry. The .NET method signature uses `params object[]`, which
    # PowerShell doesn't auto-expand — wrap arguments in [object[]].
    [Sentry.SentrySdk]::Logger.LogInfo(
        'User {0} ran send-logs.ps1 on {1} (PowerShell {2})',
        ([object[]]@($user, $host_, $psVersion)))

    # Logs are buffered and flushed in the background. Give them a moment to send.
    [Sentry.SentrySdk]::Flush([TimeSpan]::FromSeconds(5)) | Out-Null
} finally {
    Stop-Sentry
}
