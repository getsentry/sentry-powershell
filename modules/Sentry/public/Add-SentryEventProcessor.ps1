. "$privateDir/Get-CurrentOptions.ps1"

<#
.SYNOPSIS
    Registers a global event processor that runs on every event before it is sent to Sentry.
.DESCRIPTION
    The script block receives the Sentry event via the automatic variable $_ (matching the
    convention used by Edit-SentryScope). Return the event to send it, or $null to drop it.
.EXAMPLE
    PS> Add-SentryEventProcessor { $_.SetTag('host', $env:COMPUTERNAME); $_ }
.EXAMPLE
    PS> Add-SentryEventProcessor {
            if ($_.Message -match 'secret') { return $null }
            $_
        }
#>
function Add-SentryEventProcessor {
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $options = Get-CurrentOptions
    if ($null -eq $options) {
        throw 'Sentry is not initialized. Call Start-Sentry before adding an event processor.'
    }

    # Wrap the user's script block in a pipeline so that $_ is bound to the event,
    # matching Edit-SentryScope's convention.
    $wrapped = {
        param([Sentry.SentryEvent] $event_)
        $event_ | ForEach-Object $ScriptBlock
    }.GetNewClosure()

    $options.AddEventProcessor(
        [ScriptBlockEventProcessor]::new($wrapped, $options.DiagnosticLogger))
}
