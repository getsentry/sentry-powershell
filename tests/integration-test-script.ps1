Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Import-Module ../modules/Sentry/Sentry.psd1
. ./utils.ps1

$events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
$transport = [RecordingTransport]::new()
StartSentryForEventTests ([ref] $events) ([ref] $transport)

try
{
    funcA 'throw' 'error'
}
catch
{
    $_ | Out-Sentry | Out-Null
}

$events[0].SentryThreads.Stacktrace.Frames | ForEach-Object {
    Write-Output '----------------'
    Write-Output $_
}
