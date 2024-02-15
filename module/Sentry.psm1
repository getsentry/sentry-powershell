$publicDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'public'
$privateDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'private'

. "$publicDir/Out-Sentry.ps1"
. "$publicDir/Invoke-WithSentry.ps1"