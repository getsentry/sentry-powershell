# Regression script for https://github.com/getsentry/sentry-powershell/issues/38
#
# Starts Sentry, captures a message, and exits WITHOUT calling Stop-Sentry to verify that
# events are still flushed/delivered automatically on process exit (and that the process
# exits cleanly without hanging).
#
# A file-writing transport (FileTransport, defined in utils.ps1) is used instead of a network
# call so that delivery can be observed from the parent process after this one exits, without
# relying on networking/open ports in CI.
#
# Usage: pwsh -File exit-flush-test-script.ps1 <output-file>
param(
    [Parameter(Mandatory)]
    [string] $OutputFile
)

Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../modules/Sentry/Sentry.psd1"
. "$PSScriptRoot/utils.ps1"

Start-Sentry {
    $_.Dsn = 'https://key@127.0.0.1/1'
    $_.Transport = [FileTransport]::new($OutputFile)
}

$null = [Sentry.SentrySdk]::CaptureMessage('hello-from-exit-flush-test')

# Intentionally NO Stop-Sentry call here - delivery must happen automatically on exit.
Write-Host 'CHILD_DONE'
