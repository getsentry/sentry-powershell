$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'
$moduleInfo = Import-PowerShellDataFile (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Sentry.psd1')

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

Add-Type -TypeDefinition (Get-Content "$privateDir/SentryEventProcessor.cs" -Raw) -ReferencedAssemblies $sentryDllPath -Debug:$false
. "$privateDir/SentryEventProcessor.ps1"

Get-ChildItem $publicDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}
