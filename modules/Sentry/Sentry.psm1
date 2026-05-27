$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'
$moduleInfo = Import-PowerShellDataFile (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Sentry.psd1')

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')
# ScriptBlockEventProcessor.cs uses System.Management.Automation.ScriptBlock.
$automationDllPath = [System.Management.Automation.PSObject].Assembly.Location

function Add-SentryInlineType([string] $sourceFile, [string[]] $extraReferences) {
    $addTypeParams = @{
        TypeDefinition       = (Get-Content $sourceFile -Raw)
        ReferencedAssemblies = @($sentryDllPath) + $extraReferences
        Debug                = $false
    }
    # -CompilerOptions is PS Core only; suppress CS1701/CS1702 (harmless binding-redirect noise) when available.
    if ($PSEdition -eq 'Core') {
        $addTypeParams['CompilerOptions'] = '/nowarn:CS1701;CS1702'
    }
    Add-Type @addTypeParams
}

Add-SentryInlineType "$privateDir/SentryEventProcessor.cs" @()
Add-SentryInlineType "$privateDir/ScriptBlockEventProcessor.cs" @($automationDllPath)
. "$privateDir/SentryEventProcessor.ps1"

Get-ChildItem $publicDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}
