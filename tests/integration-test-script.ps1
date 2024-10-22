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
    '----------------' | Out-String
    $frame = $_
    $properties = $frame | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
    foreach ($prop in $properties)
    {
        $value = $frame.$prop | Out-String -Width 500
        "$($prop):$value"
    }
}
