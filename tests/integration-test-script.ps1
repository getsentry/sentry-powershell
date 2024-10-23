Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Import-Module ./modules/Sentry/Sentry.psd1
. ./tests/utils.ps1
. ./tests/throwingshort.ps1

function funcA
{
    # Call to another file
    funcC
}

$events = [System.Collections.Generic.List[Sentry.SentryEvent]]::new();
$transport = [RecordingTransport]::new()
StartSentryForEventTests ([ref] $events) ([ref] $transport)

try
{
    funcA
}
catch
{
    $_ | Out-Sentry | Out-Null
}

$thread = $events[0].SentryThreads | Where-Object { $_.Id -eq 0 }
$thread.Stacktrace.Frames | ForEach-Object {
    '----------------' | Out-String
    $frame = $_
    $properties = $frame | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
    foreach ($prop in $properties)
    {
        $value = $frame.$prop | Out-String -Width 500
        if ("$value" -ne '')
        {
            "$($prop): $value".TrimEnd()
        }
    }
}
