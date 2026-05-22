$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'
$moduleInfo = Import-PowerShellDataFile (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'Sentry.psd1')

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

# Suppress CS1701/CS1702: Sentry.dll references System.Runtime at a version that differs from
# the one loaded by the PowerShell host (e.g. pwsh on .NET 10 vs Sentry.dll's net9.0 metadata).
# The runtime binds successfully; the warnings are noise.
Add-Type -TypeDefinition (Get-Content "$privateDir/SentryEventProcessor.cs" -Raw) -ReferencedAssemblies $sentryDllPath -CompilerOptions '/nowarn:CS1701;CS1702' -Debug:$false
. "$privateDir/SentryEventProcessor.ps1"

Get-ChildItem $publicDir -Filter '*.ps1' | ForEach-Object {
    . $_.FullName
}
