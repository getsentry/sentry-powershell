# Maps common file extensions that aren't guaranteed to be in OS MIME databases
# to a content type that Sentry will recognize for attachment preview to work.
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
