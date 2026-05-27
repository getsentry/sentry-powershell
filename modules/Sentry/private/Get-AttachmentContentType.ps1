# Maps common file extensions (especially PowerShell-flavored ones that aren't
# in most OS MIME databases) to a content type suitable for the Sentry server's
# attachment preview. Returns $null when no match is known, in which case the
# caller should leave content-type unset and let the server default it.
$script:SentryAttachmentContentTypes = @{
    # PowerShell
    '.ps1'    = 'text/plain'
    '.psm1'   = 'text/plain'
    '.psd1'   = 'text/plain'
    '.ps1xml' = 'application/xml'
    '.pssc'   = 'text/plain'
    '.psrc'   = 'text/plain'

    # Plain text / logs / config
    '.txt'    = 'text/plain'
    '.log'    = 'text/plain'
    '.md'     = 'text/plain'
    '.ini'    = 'text/plain'
    '.cfg'    = 'text/plain'
    '.conf'   = 'text/plain'
    '.yaml'   = 'text/plain'
    '.yml'    = 'text/plain'
    '.toml'   = 'text/plain'

    # Structured
    '.json'   = 'application/json'
    '.xml'    = 'application/xml'
    '.csv'    = 'text/csv'
    '.html'   = 'text/html'
    '.htm'    = 'text/html'
    '.css'    = 'text/css'
    '.js'     = 'text/javascript'
    '.sql'    = 'text/plain'
}

function Get-AttachmentContentType {
    param([string] $FileName)

    if ([string]::IsNullOrEmpty($FileName)) {
        return $null
    }
    $ext = [System.IO.Path]::GetExtension($FileName)
    if ([string]::IsNullOrEmpty($ext)) {
        return $null
    }
    return $script:SentryAttachmentContentTypes[$ext.ToLowerInvariant()]
}
