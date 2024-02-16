$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

# On PowerShell 7.3, we need to ignore a warning about using .NET 6 Sentry.assembly (that targets System.Runtime 6.0.0)
# while we actually target System.Runtime 7.0.0. The problem is no .NET7 version of Sentry anymore.
$ignoreCsCompilerWarnings = ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -eq 3)
Add-Type -TypeDefinition (Get-Content "$privateDir/SentryEventProcessor.cs" -Raw) -ReferencedAssemblies $sentryDllPath -IgnoreWarnings:$ignoreCsCompilerWarnings


. "$publicDir/Invoke-WithSentry.ps1"
. "$publicDir/Out-Sentry.ps1"
. "$publicDir/Start-Sentry.ps1"
. "$publicDir/Stop-Sentry.ps1"
