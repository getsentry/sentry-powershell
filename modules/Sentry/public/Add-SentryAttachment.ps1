function Add-SentryAttachment {
    <#
    .SYNOPSIS
        Adds a file or byte attachment to the current Sentry scope.
    .DESCRIPTION
        Wraps Scope.AddAttachment and, when -ContentType is not specified,
        infers a sensible content type from the file extension so that the
        Sentry UI can preview common text formats (including PowerShell
        scripts).
    .PARAMETER Path
        Path to a file to attach.
    .PARAMETER Bytes
        Raw bytes to attach. Must be combined with -FileName.
    .PARAMETER FileName
        File name to associate with byte data.
    .PARAMETER ContentType
        Optional MIME type. If omitted, a default is chosen based on the
        file extension; if no default is known, content-type is left unset.
    .PARAMETER Type
        Sentry attachment type. Defaults to Default.
    .EXAMPLE
        PS> Add-SentryAttachment -Path $PSCommandPath
    .EXAMPLE
        PS> $PSCommandPath | Add-SentryAttachment
    .EXAMPLE
        PS> Add-SentryAttachment -Bytes $bytes -FileName 'data.json'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path', ValueFromPipeline = $true)]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]] $Bytes,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [string] $FileName,

        [string] $ContentType,

        [Sentry.AttachmentType] $Type = [Sentry.AttachmentType]::Default
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            # Resolve relative paths against PowerShell's $PWD. The Sentry SDK reads
            # the file lazily via .NET I/O, which resolves against [Environment]::CurrentDirectory
            # — that can diverge from $PWD after Set-Location, so resolve eagerly here.
            $Path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
            $resolvedFileName = [System.IO.Path]::GetFileName($Path)
            $resolvedContentType = if ($PSBoundParameters.ContainsKey('ContentType')) { $ContentType } else { Get-AttachmentContentType $resolvedFileName }
            Edit-SentryScope { $_.AddAttachment($Path, $Type, $resolvedContentType) }.GetNewClosure()
        } else {
            $resolvedContentType = if ($PSBoundParameters.ContainsKey('ContentType')) { $ContentType } else { Get-AttachmentContentType $FileName }
            Edit-SentryScope { $_.AddAttachment($Bytes, $FileName, $Type, $resolvedContentType) }.GetNewClosure()
        }
    }
}
