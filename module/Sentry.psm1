$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'

. "$privateDir/Get-SentryAssembliesDirectory.ps1"
$sentryDllPath = (Join-Path (Get-SentryAssembliesDirectory) 'Sentry.dll')

Add-Type -TypeDefinition (Get-Content "$privateDir/SentryEventProcessor.cs" -Raw) -ReferencedAssemblies $sentryDllPath

. "$publicDir/Out-Sentry.ps1"
. "$publicDir/Invoke-WithSentry.ps1"
