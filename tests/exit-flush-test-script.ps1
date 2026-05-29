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

# When this script is launched cross-edition - e.g. powershell.exe (Windows PowerShell) spawned
# from a pwsh (PowerShell Core) host - the inherited $env:PSModulePath points only at the launching
# edition's module directories. That prevents Windows PowerShell from autoloading its built-in
# modules (notably Microsoft.PowerShell.Utility, which provides Import-PowerShellDataFile used while
# importing the Sentry module). Reset to the machine default so built-in modules are discoverable.
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $env:PSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
}

Import-Module "$PSScriptRoot/../modules/Sentry/Sentry.psd1"
. "$PSScriptRoot/utils.ps1"

Start-Sentry {
    $_.Dsn = 'https://key@127.0.0.1/1'
    $_.Transport = [FileTransport]::new($OutputFile)
}

$null = [Sentry.SentrySdk]::CaptureMessage('hello-from-exit-flush-test')

# Intentionally NO Stop-Sentry call here - delivery must happen automatically on exit.
Write-Host 'CHILD_DONE'
