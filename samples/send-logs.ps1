<#
.SYNOPSIS
    Demonstrates sending structured logs to Sentry from PowerShell.
.DESCRIPTION
    Shows how to enable Sentry Logs (https://docs.sentry.io/platforms/dotnet/logs/)
    in the PowerShell module and emit log messages at various severity levels,
    including templated messages with structured parameters and custom attributes.
.EXAMPLE
    PS> ./send-logs.ps1
.LINK
    https://docs.sentry.io/platforms/dotnet/logs/
#>

# Import the Sentry module. In your code, you would just use `Import-Module Sentry`.
Import-Module $PSScriptRoot/../modules/Sentry/Sentry.psd1

# Start the Sentry client. Set EnableLogs = $true to opt in to Logs.
Start-Sentry {
    $_.Dsn = 'https://997874440feaba4ecc65c1e25df7912b@o447951.ingest.us.sentry.io/4508073336176640'
    $_.Debug = $true
    $_.EnableLogs = $true
}

try {
    # Each call sends one log record at the given severity. Level defaults to Info.
    Write-SentryLog -Level Trace 'Trace from PowerShell'
    Write-SentryLog -Level Debug 'Debug from PowerShell'
    Write-SentryLog 'Info from PowerShell'
    Write-SentryLog -Level Warning 'Warning from PowerShell'
    Write-SentryLog -Level Error 'Error from PowerShell'
    Write-SentryLog -Level Fatal 'Fatal from PowerShell'

    # Templated messages use positional placeholders ({0}, {1}, ...). Each value
    # passed via -Parameters is captured as a structured attribute on the log
    # record so you can search/filter on it in Sentry.
    $user = $env:USER ?? $env:USERNAME
    $hostName = [System.Net.Dns]::GetHostName()
    $psVersion = $PSVersionTable.PSVersion.ToString()
    Write-SentryLog -Level Info `
        -Message 'User {0} ran send-logs.ps1 on {1} (PowerShell {2})' `
        -Parameters $user, $hostName, $psVersion

    # -Attributes attaches arbitrary key/value pairs to the log record.
    Write-SentryLog -Level Warning `
        -Message 'Disk usage on {0} is at {1}%' `
        -Parameters $hostName, 92 `
        -Attributes @{ region = 'us-east-1'; mount = '/var' }

    # Logs are buffered and flushed in the background. Give them a moment to send.
    [Sentry.SentrySdk]::Flush([TimeSpan]::FromSeconds(5)) | Out-Null
} finally {
    Stop-Sentry
}
