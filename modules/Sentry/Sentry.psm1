$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'
$moduleInfo = Import-PowerShellDataFile (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Sentry.psd1')

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

$addTypeParams = @{
    TypeDefinition       = (Get-Content "$privateDir/SentryEventProcessor.cs" -Raw)
    ReferencedAssemblies = $sentryDllPath
    Debug                = $false
}
# -CompilerOptions is PS Core only; suppress CS1701/CS1702 (harmless binding-redirect noise) when available.
if ($PSEdition -eq 'Core') {
    $addTypeParams['CompilerOptions'] = '/nowarn:CS1701;CS1702'
}
Add-Type @addTypeParams
. "$privateDir/SentryEventProcessor.ps1"

Get-ChildItem $publicDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}
