<#
.SYNOPSIS
    Demonstrates attaching files and byte data to a Sentry event.
.DESCRIPTION
    Shows how to use Add-SentryAttachment to upload supporting files alongside
    an event. When -ContentType is not specified, the cmdlet infers one from
    the file extension so the Sentry UI can preview common text formats
    (including PowerShell scripts) instead of falling back to
    application/octet-stream.
.EXAMPLE
    PS> ./send-attachment.ps1
.LINK
    https://docs.sentry.io/platforms/powershell/enriching-events/attachments/
#>

# Import the Sentry module. In your code, you would just use `Import-Module Sentry`.
Import-Module $PSScriptRoot/../modules/Sentry/Sentry.psd1

Start-Sentry {
    $_.Dsn = 'https://997874440feaba4ecc65c1e25df7912b@o447951.ingest.us.sentry.io/4508073336176640'
    $_.Debug = $true
}

try {
    # 1) Attach a file by path. The extension (.ps1) is recognized as text,
    #    so Sentry will render it inline in the event's Attachments tab.
    #    A path can also be supplied from the pipeline:
    #        $PSCommandPath | Add-SentryAttachment
    Add-SentryAttachment -Path $PSCommandPath

    # 2) Attach raw bytes with a filename hint. .json maps to application/json
    #    so the UI shows a JSON preview.
    $payload = @{ host = [System.Net.Dns]::GetHostName(); psVersion = $PSVersionTable.PSVersion.ToString() } |
        ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    Add-SentryAttachment -Bytes $bytes -FileName 'context.json'

    # 3) Explicit -ContentType always wins over the inferred default.
    Add-SentryAttachment -Path $PSCommandPath -ContentType 'text/x-powershell'

    # Capture an event so the attachments have something to ride along with.
    # All three attachments above are attached to this event via the current scope.
    'Sample event with attachments' | Out-Sentry
} finally {
    Stop-Sentry
}
